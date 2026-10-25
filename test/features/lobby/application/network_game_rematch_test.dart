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
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match/domain/rematch_offer.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';

import '../../../support/fakes.dart';
import '../../../support/match_fixtures.dart';
import '../support/fake_game_lobby.dart';

/// Реванш сетевой игры (ADR 0028): предложение доходит до стола, согласие обоих возвращает игру в комнату, а следующая
/// партия открывается новым столом в той же игре.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late FakeScheduler scheduler;
  late ActiveNetworkGame hostActive;
  late ActiveNetworkGame guestActive;
  late HostNetworkGame hostGame;
  late JoinNetworkGame joinGame;
  late DiscoverNetworkGames discover;

  setUpAll(() async => content = await loadBaseContent());

  setUp(() {
    final lobby = FakeGameLobby();
    scheduler = FakeScheduler();
    hostActive = ActiveNetworkGame();
    guestActive = ActiveNetworkGame();
    final setup = LoadNetworkSetup(
      LoadGameContent(AssetContentSource.basePack(rootBundle)),
      const FakeAppInfo(),
      WatchSettings(InMemorySettingsRepository()),
    );
    hostGame = HostNetworkGame(setup, lobby, hostActive, SecureEntropy(), scheduler, requireAdmission: false);
    joinGame = JoinNetworkGame(setup, lobby, guestActive, scheduler);
    discover = DiscoverNetworkGames(setup, lobby);
  });

  tearDown(() async {
    await hostActive.current?.close();
    await guestActive.current?.close();
  });

  /// Оба выбирают колоды и жмут «Готов», отсчёт проходит, партия начинается.
  Future<void> startMatch(NetworkGame host, NetworkGame guest) async {
    final north = realDeck(content, Faction.northernRealms, id: 'north');
    final monsters = realDeck(content, Faction.monsters, id: 'monsters');
    host.ready(north.toEngineDeck(), deckName: north.name);
    guest.ready(monsters.toEngineDeck());
    await scheduler.elapse(const Duration(seconds: 4));
    await scheduler.flush();
  }

  /// Игра с обоими игроками, партия сыграна: гость сдался, у обоих открыт стол и копятся его обновления.
  Future<({NetworkGame host, NetworkGame guest, MatchSession hostSession, MatchSession guestSession})> finished(
    List<TableUpdate> hostUpdates,
    List<TableUpdate> guestUpdates,
  ) async {
    final host = (await hostGame(gameName: 'Цири', playerName: 'Цири') as NetworkGameOpened).game;
    final found = (await discover().firstWhere((games) => games.isNotEmpty)).single;
    final guest = (await joinGame(found: found.found, playerName: 'Вереск') as NetworkGameOpened).game;
    await scheduler.flush();
    await scheduler.flush();
    await startMatch(host, guest);
    final hostSession = host.openMatch();
    final guestSession = guest.openMatch();
    hostSession.table.updates.listen(hostUpdates.add);
    guestSession.table.updates.listen(guestUpdates.add);
    await scheduler.flush();
    guestSession.table.submit(Seat.two, const Resign());
    await scheduler.flush();
    await scheduler.flush();
    return (host: host, guest: guest, hostSession: hostSession, guestSession: guestSession);
  }

  List<RematchOffer> offers(List<TableUpdate> updates) => [
    for (final update in updates)
      if (update is TableRematchChanged) update.offer,
  ];

  test('сдача кончает партию, пока никто не просил реванш: предложений нет', () async {
    final hostUpdates = <TableUpdate>[];
    final guestUpdates = <TableUpdate>[];
    await finished(hostUpdates, guestUpdates);
    expect(hostUpdates.whereType<ViewsChanged>().last.views.values.single.phase, MatchPhase.finished);
    expect(offers(hostUpdates), isEmpty);
    expect(offers(guestUpdates), isEmpty);
  });

  test('предложение гостя доходит до хоста как приглашение, а гостю остаётся «жду ответа»', () async {
    final hostUpdates = <TableUpdate>[];
    final guestUpdates = <TableUpdate>[];
    final game = await finished(hostUpdates, guestUpdates);

    (game.guestSession.table as RematchTable).requestRematch();
    await scheduler.flush();
    await scheduler.flush();

    expect(offers(guestUpdates).single.stage, RematchStage.requested);
    expect(offers(hostUpdates).single.stage, RematchStage.invited);
    expect(offers(hostUpdates).single.window, const Duration(seconds: 30));
  });

  test('оба согласны: столы прежней партии узнают об этом, обе комнаты ждут колоды, игры остаются открытыми', () async {
    final hostUpdates = <TableUpdate>[];
    final guestUpdates = <TableUpdate>[];
    final game = await finished(hostUpdates, guestUpdates);

    (game.guestSession.table as RematchTable).requestRematch();
    (game.hostSession.table as RematchTable).requestRematch();
    await scheduler.flush();
    await scheduler.flush();

    expect(hostUpdates.last, isA<TableRematchAgreed>());
    expect(guestUpdates.last, isA<TableRematchAgreed>());
    for (final side in [game.host, game.guest]) {
      expect(side.room.started, isFalse);
      expect(side.room.myStage, LobbyStage.choosing);
      expect(side.room.myLeader, isNull);
      expect(side.room.opponent?.stage, LobbyStage.choosing);
      expect(side.room.end, isNull);
      expect(side.handedOver, isFalse);
      expect(side.isClosed, isFalse);
    }

    // Закрытие прежних столов (экран уходит в комнату) игры не закрывает.
    await game.hostSession.table.close();
    await game.guestSession.table.close();
    expect(game.host.isClosed, isFalse);
    expect(game.guest.isClosed, isFalse);
  });

  test('после согласия колоды выбирают заново, и вторая партия открывается новым столом', () async {
    final hostUpdates = <TableUpdate>[];
    final guestUpdates = <TableUpdate>[];
    final game = await finished(hostUpdates, guestUpdates);
    (game.guestSession.table as RematchTable).requestRematch();
    (game.hostSession.table as RematchTable).requestRematch();
    await scheduler.flush();
    await scheduler.flush();
    await game.hostSession.table.close();
    await game.guestSession.table.close();

    await startMatch(game.host, game.guest);

    expect(game.host.room.started, isTrue);
    final second = game.host.openMatch();
    final update = await second.table.updates.first;
    expect(
      update,
      isA<ViewsChanged>().having((update) => update.views.values.single.phase, 'phase', MatchPhase.redraw),
    );
    await second.table.close();
    expect(game.host.isClosed, isTrue, reason: 'закрытие стола текущей партии закрывает игру');
  });

  test('хост ушёл с экрана итога: гость узнаёт, что соперника нет', () async {
    final hostUpdates = <TableUpdate>[];
    final guestUpdates = <TableUpdate>[];
    final game = await finished(hostUpdates, guestUpdates);

    await game.hostSession.table.close();
    await scheduler.flush();
    await scheduler.flush();

    expect(offers(guestUpdates).last.stage, RematchStage.opponentGone);
  });

  test('гость ушёл с экрана итога: хост узнаёт, что соперника нет', () async {
    final hostUpdates = <TableUpdate>[];
    final guestUpdates = <TableUpdate>[];
    final game = await finished(hostUpdates, guestUpdates);

    await game.guestSession.table.close();
    await scheduler.flush();
    await scheduler.flush();

    expect(offers(hostUpdates).last.stage, RematchStage.opponentGone);
  });

  test('время вышло: оба видят, что реванша не будет', () async {
    final hostUpdates = <TableUpdate>[];
    final guestUpdates = <TableUpdate>[];
    final game = await finished(hostUpdates, guestUpdates);

    (game.guestSession.table as RematchTable).requestRematch();
    await scheduler.flush();
    await scheduler.elapse(const Duration(seconds: 31));

    expect(offers(guestUpdates).last.stage, RematchStage.expired);
    expect(offers(hostUpdates).last.stage, RematchStage.expired);
  });
}
