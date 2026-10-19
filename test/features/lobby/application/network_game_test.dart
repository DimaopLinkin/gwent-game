import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/lobby/application/active_network_game.dart';
import 'package:gwent/src/features/lobby/application/discover_network_games.dart';
import 'package:gwent/src/features/lobby/application/host_network_game.dart';
import 'package:gwent/src/features/lobby/application/join_network_game.dart';
import 'package:gwent/src/features/lobby/application/load_network_setup.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchMode;
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';

import '../../../support/fakes.dart';
import '../../../support/match_fixtures.dart';
import '../support/fake_game_lobby.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late FakeGameLobby lobby;
  late FakeScheduler scheduler;
  late ActiveNetworkGame hostActive;
  late ActiveNetworkGame guestActive;
  late HostNetworkGame hostGame;
  late JoinNetworkGame joinGame;
  late DiscoverNetworkGames discover;

  setUpAll(() async => content = await loadBaseContent());

  setUp(() {
    lobby = FakeGameLobby();
    scheduler = FakeScheduler();
    hostActive = ActiveNetworkGame();
    guestActive = ActiveNetworkGame();
    final setup = LoadNetworkSetup(
      LoadGameContent(AssetContentSource.basePack(rootBundle)),
      const FakeAppInfo(),
      WatchSettings(InMemorySettingsRepository()),
    );
    hostGame = HostNetworkGame(setup, lobby, hostActive, SecureEntropy(), scheduler);
    joinGame = JoinNetworkGame(setup, lobby, guestActive, scheduler);
    discover = DiscoverNetworkGames(setup, lobby);
  });

  tearDown(() async {
    await hostActive.current?.close();
    await guestActive.current?.close();
  });

  /// Хост создаёт партию, гость находит её и входит; возвращает обе игры, когда у обоих есть соперник.
  Future<(NetworkGame, NetworkGame)> connected() async {
    final hosted = await hostGame(gameName: 'Цири', playerName: 'Цири');
    final host = (hosted as NetworkGameOpened).game;
    final found = (await discover().firstWhere((games) => games.isNotEmpty)).single;
    final joined = await joinGame(found: found.found, playerName: 'Вереск');
    final guest = (joined as NetworkGameOpened).game;
    await scheduler.flush();
    await scheduler.flush();
    return (host, guest);
  }

  test('хост объявляет партию, гость находит её и входит: у каждого есть соперник с именем', () async {
    final (host, guest) = await connected();

    expect(host.isHost, isTrue);
    expect(host.title, 'Цири');
    expect(host.room.seat, Seat.one);
    expect(host.room.opponent, const RoomOpponent(name: 'Вереск', online: true));
    expect(guest.room.seat, Seat.two);
    expect(guest.room.opponent?.name, 'Цири');
    expect(guest.room.link, RoomLink.online);
  });

  test('пока в партии есть соперник, объявление закрыто, а когда он ушёл, открывается снова', () async {
    final (host, guest) = await connected();
    final hosted = lobby.hosted.values.single;
    expect(hosted.ad.open, isFalse);

    await guest.leave();
    await scheduler.flush();
    await scheduler.flush();

    expect(host.room.opponent, isNull);
    expect(hosted.ad.open, isTrue);
  });

  test('поиск показывает совместимую партию', () async {
    await hostGame(gameName: 'Цири', playerName: 'Цири');

    final games = await discover().firstWhere((games) => games.isNotEmpty);

    expect(games.single.joinable, isTrue);
    expect(games.single.found.ad.hostName, 'Цири');
  });

  test('партия с другими данными карт остаётся в списке с причиной, и гость к ней не подключается', () async {
    const foreign = GameAd(
      id: 'foreign',
      hostName: 'Эмиель',
      ruleset: Ruleset(id: 'other-pack', hash: 'sha256:0', engineVersion: 1),
    );
    await lobby.host(foreign);

    final games = await discover().firstWhere((games) => games.isNotEmpty);
    expect(games.single.refusal, JoinRefusal.rulesetMismatch);
    expect(games.single.joinable, isFalse);

    final result = await joinGame(found: games.single.found, playerName: 'Вереск');
    expect(result, isA<NetworkRefused>().having((refused) => refused.reason, 'reason', JoinRefusal.rulesetMismatch));
    expect(lobby.joinCalls, 0, reason: 'несовместимая партия отклоняется до соединения');
  });

  test('гость видит, что делает соперник: выбор колоды, лидер, готовность', () async {
    final (host, guest) = await connected();
    final deck = realDeck(content, Faction.northernRealms, id: 'north');

    host.reportStage(LobbyStage.building);
    await scheduler.flush();
    expect(guest.room.opponent?.stage, LobbyStage.building);

    host.reportStage(LobbyStage.chosen, leader: LeaderId(deck.leaderId));
    await scheduler.flush();
    expect(guest.room.opponent?.stage, LobbyStage.chosen);
    expect(guest.room.opponent?.leader, LeaderId(deck.leaderId));

    host.ready(deck.toEngineDeck(), deckName: deck.name);
    await scheduler.flush();
    expect(host.room.myStage, LobbyStage.ready);
    expect(guest.room.opponent?.stage, LobbyStage.ready);
  });

  test('оба готовы: идёт отсчёт, по его концу партия начинается, а стол выдаёт проекцию своего места', () async {
    final (host, guest) = await connected();
    final north = realDeck(content, Faction.northernRealms, id: 'north');
    final monsters = realDeck(content, Faction.monsters, id: 'monsters');

    host.ready(north.toEngineDeck(), deckName: north.name);
    guest.ready(monsters.toEngineDeck());
    await scheduler.flush();
    await scheduler.flush();
    expect(host.room.countdown, const Duration(seconds: 3));
    expect(guest.room.countdown, const Duration(seconds: 3));
    expect(host.room.started, isFalse);

    await scheduler.elapse(const Duration(seconds: 3));
    await scheduler.flush();

    expect(host.room.started, isTrue);
    expect(guest.room.started, isTrue);
    final hostSession = host.openMatch();
    final guestSession = guest.openMatch();
    expect(hostSession.mode, MatchMode.wifi);
    expect(hostSession.table.localSeats, {Seat.one});
    expect(guestSession.table.localSeats, {Seat.two});
    expect(hostSession.deckNames, {Seat.one: north.name});
    expect(hostSession.factionIds, {Seat.one: north.factionId, Seat.two: monsters.factionId});
    expect(guestSession.factionIds, hostSession.factionIds);

    final first = await hostSession.table.updates.first as ViewsChanged;
    expect(first.views.keys, [Seat.one]);
    expect(first.views[Seat.one]!.viewer, Seat.one);
    final guestFirst = await guestSession.table.updates.first as ViewsChanged;
    expect(guestFirst.views[Seat.two]!.viewer, Seat.two);
    await hostSession.table.close();
    await guestSession.table.close();
  });

  test('отмена готовности до конца отсчёта не даёт партии начаться', () async {
    final (host, guest) = await connected();
    final north = realDeck(content, Faction.northernRealms, id: 'north');
    host.ready(north.toEngineDeck());
    guest.ready(north.toEngineDeck());
    await scheduler.flush();
    await scheduler.flush();
    expect(guest.room.countdown, isNotNull);

    await scheduler.elapse(const Duration(seconds: 1));
    guest.cancelReady();
    await scheduler.flush();
    await scheduler.flush();
    expect(host.room.countdown, isNull);
    expect(guest.room.countdown, isNull);
    expect(guest.room.myStage, LobbyStage.chosen);
    expect(host.room.opponent?.stage, LobbyStage.chosen);

    await scheduler.elapse(const Duration(seconds: 5));
    expect(host.room.started, isFalse);
    expect(guest.room.started, isFalse);
  });

  test('намерение, которое отклонил движок, возвращается столу отказом', () async {
    final (host, guest) = await connected();
    final north = realDeck(content, Faction.northernRealms, id: 'north');
    host.ready(north.toEngineDeck());
    guest.ready(north.toEngineDeck());
    await scheduler.elapse(const Duration(seconds: 4));
    await scheduler.flush();
    final session = guest.openMatch();
    final updates = StreamIterator(session.table.updates);
    expect(await updates.moveNext(), isTrue);

    // Пас во время пересдачи движок не принимает.
    session.table.submit(Seat.two, const Pass());
    await scheduler.flush();
    await scheduler.flush();

    expect(await updates.moveNext(), isTrue);
    expect(updates.current, isA<IntentRefused>().having((update) => update.intent, 'intent', const Pass()));
    await updates.cancel();
    await session.table.close();
  });

  test('хост закрыл лобби: гость узнаёт, что возвращаться некуда', () async {
    final (host, guest) = await connected();

    await host.leave();
    await scheduler.flush();
    await scheduler.flush();

    expect(guest.room.end, const RoomHostClosed());
    expect(lobby.hosted, isEmpty);
  });

  test('обрыв связи у гостя: он возвращается к хосту сам', () async {
    final (host, guest) = await connected();
    final joinsBefore = lobby.joinCalls;
    final links = <RoomLink>[];
    final subscription = guest.rooms.listen((room) => links.add(room.link));
    addTearDown(subscription.cancel);

    await lobby.hostEnds.single.close();
    await scheduler.flush();
    await scheduler.elapse(const Duration(seconds: 1));
    await scheduler.flush();
    await scheduler.flush();

    expect(links, [RoomLink.lost, RoomLink.online]);
    expect(lobby.joinCalls, joinsBefore + 1);
    expect(guest.room.link, RoomLink.online);
    expect(guest.room.opponent?.name, 'Цири');
    expect(host.room.opponent?.online, isTrue);
  });

  test('хост не возвращается за отведённое время: комната заканчивается потерей связи', () async {
    final (_, guest) = await connected();
    lobby.failJoins = 1000;

    await lobby.hostEnds.single.close();
    await scheduler.flush();
    await scheduler.elapse(guest.reconnectWindow + const Duration(seconds: 1));
    await scheduler.flush();

    expect(guest.room.end, const RoomConnectionLost());
  });

  test('хост не может объявить партию: сценарий сообщает, что сеть недоступна', () async {
    lobby.failHost = true;

    expect(await hostGame(gameName: 'Цири', playerName: 'Цири'), isA<NetworkUnavailable>());
    expect(hostActive.current, isNull);
  });

  test('хост недоступен: гость получает «не удалось подключиться» и ничего не оставляет открытым', () async {
    await hostGame(gameName: 'Цири', playerName: 'Цири');
    final found = (await discover().firstWhere((games) => games.isNotEmpty)).single;
    lobby.failJoins = 1;

    expect(await joinGame(found: found.found, playerName: 'Вереск'), isA<NetworkUnreachable>());
    expect(guestActive.current, isNull);
  });

  test('вторая игра закрывает прежнюю', () async {
    final first = (await hostGame(gameName: 'Первая', playerName: 'Цири') as NetworkGameOpened).game;
    final second = (await hostGame(gameName: 'Вторая', playerName: 'Цири') as NetworkGameOpened).game;

    expect(first.isClosed, isTrue);
    expect(hostActive.current, same(second));
  });
}
