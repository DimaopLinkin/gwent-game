import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/application/get_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/lobby/application/active_network_game.dart';
import 'package:gwent/src/features/lobby/application/discover_network_games.dart';
import 'package:gwent/src/features/lobby/application/host_network_game.dart';
import 'package:gwent/src/features/lobby/application/join_network_game.dart';
import 'package:gwent/src/features/lobby/application/load_network_setup.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/application/network_readiness.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/game_invite.dart';
import 'package:gwent/src/features/lobby/domain/network_access.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_state.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_state.dart';
import 'package:gwent/src/features/lobby/presentation/host_invite_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/host_invite_state.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_state.dart';
import 'package:gwent/src/features/lobby/presentation/room_cubit.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent_engine/gwent_engine.dart' as engine;
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';

import '../../../support/fakes.dart';
import '../../../support/match_fixtures.dart';
import '../support/fake_game_lobby.dart';
import '../support/lobby_fakes.dart';

const NetworkProblem wifiOff = NetworkProblem.wifiOff;
const NetworkProblem explainer = NetworkProblem.localNetworkExplainer;
const NetworkProblem denied = NetworkProblem.localNetworkDenied;

/// Сеть недоступна по названной причине.
Matcher _unavailable(NetworkProblem problem) =>
    isA<NetworkUnavailable>().having((result) => result.problem, 'problem', problem);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late FakeGameLobby lobby;
  late FakeScheduler scheduler;
  late InMemorySettingsRepository settings;
  late InMemoryDeckRepository decks;
  late ActiveNetworkGame hostActive;
  late ActiveNetworkGame guestActive;
  late HostNetworkGame hostGame;
  late JoinNetworkGame joinGame;
  late DiscoverNetworkGames discover;
  late LoadDeckRules loadRules;
  late FakeNetworkAccess access;
  late NetworkReadiness readiness;

  setUpAll(() async => content = await loadBaseContent());

  setUp(() {
    lobby = FakeGameLobby();
    scheduler = FakeScheduler();
    settings = InMemorySettingsRepository();
    access = FakeNetworkAccess();
    readiness = NetworkReadiness(access, settings);
    decks = InMemoryDeckRepository([
      realDeck(content, engine.Faction.northernRealms, id: 'north'),
      realDeck(content, engine.Faction.monsters, id: 'monsters').copyWith(cards: const {}),
    ]);
    hostActive = ActiveNetworkGame();
    guestActive = ActiveNetworkGame();
    final loadContent = LoadGameContent(AssetContentSource.basePack(rootBundle));
    final setup = LoadNetworkSetup(loadContent, const FakeAppInfo(), WatchSettings(settings));
    hostGame = HostNetworkGame(setup, lobby, hostActive, SecureEntropy(), scheduler);
    joinGame = JoinNetworkGame(setup, lobby, guestActive, scheduler);
    discover = DiscoverNetworkGames(setup, lobby);
    loadRules = LoadDeckRules(GameContentDeckRulesSource(loadContent));
  });

  tearDown(() async {
    await hostActive.current?.close();
    await guestActive.current?.close();
  });

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await scheduler.flush();
    }
  }

  group('создание игры', () {
    CreateGameCubit makeCubit() {
      final cubit = CreateGameCubit(hostGame, WatchSettings(settings), readiness, fallbackName: 'Игрок');
      addTearDown(cubit.close);
      return cubit;
    }

    test('название по умолчанию — имя из настроек, а без него — имя по умолчанию', () async {
      await settings.save(const AppSettings(playerName: ' Цири '));
      final named = makeCubit();
      await named.stream.firstWhere((state) => state is CreateGameForm);
      expect((named.state as CreateGameForm).initialName, 'Цири');

      await settings.save(const AppSettings());
      final anonymous = makeCubit();
      await anonymous.stream.firstWhere((state) => state is CreateGameForm);
      expect((anonymous.state as CreateGameForm).initialName, 'Игрок');
    });

    test('партия создаётся с введённым названием и объявляется в сети', () async {
      final cubit = makeCubit();
      await cubit.stream.firstWhere((state) => state is CreateGameForm);

      await cubit.create('  Ночной Гвинт ');

      expect(cubit.state, isA<CreateGameCreated>());
      expect(lobby.hosted.values.single.ad.hostName, 'Ночной Гвинт');
      expect(hostActive.current?.title, 'Ночной Гвинт');
    });

    test('игрок ушёл с экрана, пока партия создавалась: она закрывается и не остаётся в сети', () async {
      final cubit = makeCubit();
      await cubit.stream.firstWhere((state) => state is CreateGameForm);

      final creating = cubit.create('Цири');
      await cubit.close();
      await creating;
      await settle();

      expect(hostActive.current, isNull);
      expect(lobby.hosted, isEmpty);
    });

    test('пустое название заменяется именем игрока', () async {
      final cubit = makeCubit();
      await cubit.stream.firstWhere((state) => state is CreateGameForm);

      await cubit.create('   ');

      expect(lobby.hosted.values.single.ad.hostName, 'Игрок');
    });

    test('Wi-Fi выключен, но есть мобильная сеть: партия создаётся', () async {
      final cubit = makeCubit();
      await cubit.stream.firstWhere((state) => state is CreateGameForm);
      access
        ..wifiOn = false
        ..mobileOn = true;

      await cubit.create('Цири');

      expect(cubit.state, isA<CreateGameCreated>());
    });

    test('Wi-Fi выключен: партия не создаётся, причина названа', () async {
      final cubit = makeCubit();
      await cubit.stream.firstWhere((state) => state is CreateGameForm);
      access.wifiOn = false;

      await cubit.create('Цири');

      expect(cubit.state, isA<CreateGameFailed>().having((failed) => failed.result, 'result', _unavailable(wifiOff)));
      expect(lobby.hosted, isEmpty);

      await cubit.openSettings(NetworkProblem.wifiOff);
      expect(access.openedSettings, ['wifi']);
    });

    test('iOS: сначала пояснение, «Продолжить» запоминает его и создаёт партию с тем же названием', () async {
      access.asksLocalNetworkPermission = true;
      final cubit = makeCubit();
      await cubit.stream.firstWhere((state) => state is CreateGameForm);

      await cubit.create('Ночной Гвинт');
      expect(
        cubit.state,
        isA<CreateGameFailed>().having((failed) => failed.result, 'result', _unavailable(explainer)),
      );
      expect(lobby.hosted, isEmpty);

      await cubit.continueAfterExplainer();

      expect(cubit.state, isA<CreateGameCreated>());
      expect(lobby.hosted.values.single.ad.hostName, 'Ночной Гвинт');
      expect(settings.saved.localNetworkExplained, isTrue);
    });

    test('iOS: служба сети отказала после пояснения — доступ к локальной сети запрещён', () async {
      access.asksLocalNetworkPermission = true;
      await settings.save(const AppSettings(localNetworkExplained: true));
      final cubit = makeCubit();
      await cubit.stream.firstWhere((state) => state is CreateGameForm);
      lobby.failHost = true;

      await cubit.create('Цири');

      expect(cubit.state, isA<CreateGameFailed>().having((failed) => failed.result, 'result', _unavailable(denied)));
    });

    test('если сеть недоступна, остаётся причина, а «Повторить» создаёт партию заново', () async {
      final cubit = makeCubit();
      await cubit.stream.firstWhere((state) => state is CreateGameForm);
      lobby.failHost = true;

      await cubit.create('Цири');
      expect(
        cubit.state,
        isA<CreateGameFailed>().having((failed) => failed.result, 'result', isA<NetworkUnavailable>()),
      );

      await cubit.create('Цири');
      expect(cubit.state, isA<CreateGameCreated>());
    });
  });

  group('поиск игр', () {
    FindGamesCubit makeCubit() {
      final cubit = FindGamesCubit(discover, joinGame, WatchSettings(settings), readiness, fallbackName: 'Гость');
      addTearDown(cubit.close);
      return cubit;
    }

    test('список обновляется сам: партия появляется и пропадает', () async {
      final cubit = makeCubit();
      await cubit.stream.firstWhere((state) => state is FindGamesSearching && state.games.isEmpty);

      final appeared = cubit.stream.firstWhere((state) => state is FindGamesSearching && state.games.isNotEmpty);
      await hostGame(gameName: 'Цири', playerName: 'Цири');
      expect(((await appeared) as FindGamesSearching).games.single.found.ad.hostName, 'Цири');

      final gone = cubit.stream.firstWhere((state) => state is FindGamesSearching && state.games.isEmpty);
      await hostActive.current!.close();
      await gone;
    });

    test('вход в партию: гость оказывается в комнате хоста под своим именем из настроек', () async {
      await settings.save(const AppSettings(playerName: 'Вереск'));
      await hostGame(gameName: 'Цири', playerName: 'Цири');
      final cubit = makeCubit();
      final found = await cubit.stream.firstWhere((state) => state is FindGamesSearching && state.games.isNotEmpty);

      await cubit.join((found as FindGamesSearching).games.single);

      expect(cubit.state, isA<FindGamesJoined>());
      expect(guestActive.current?.playerName, 'Вереск');
      await settle();
      expect(hostActive.current?.room.opponent?.name, 'Вереск');
    });

    test('хост недоступен: причина и «Повторить» подключается к той же партии', () async {
      await hostGame(gameName: 'Цири', playerName: 'Цири');
      final cubit = makeCubit();
      final found = await cubit.stream.firstWhere((state) => state is FindGamesSearching && state.games.isNotEmpty);
      final game = (found as FindGamesSearching).games.single;
      lobby.failJoins = 1;

      await cubit.join(game);
      expect(
        cubit.state,
        isA<FindGamesFailed>().having((failed) => failed.result, 'result', isA<NetworkUnreachable>()),
      );
      expect(guestActive.current, isNull);

      await cubit.join(game);
      expect(cubit.state, isA<FindGamesJoined>());
    });

    test('игрок ушёл с экрана, пока подключался: место у хоста не держится', () async {
      await hostGame(gameName: 'Цири', playerName: 'Цири');
      final cubit = makeCubit();
      final found = await cubit.stream.firstWhere((state) => state is FindGamesSearching && state.games.isNotEmpty);

      final joining = cubit.join((found as FindGamesSearching).games.single);
      await cubit.close();
      await joining;
      await settle();

      expect(guestActive.current, isNull);
    });

    test('отказ поиска (Wi-Fi выключен) показывается как недоступность сети', () async {
      final cubit = makeCubit();
      await cubit.stream.firstWhere((state) => state is FindGamesSearching);

      lobby.failDiscover();

      await cubit.stream.firstWhere((state) => state is FindGamesUnavailable);
    });

    test('Wi-Fi выключен: поиск не начинается, причина названа', () async {
      access.wifiOn = false;

      final cubit = makeCubit();
      final unavailable = await cubit.stream.firstWhere((state) => state is FindGamesUnavailable);

      expect((unavailable as FindGamesUnavailable).problem, wifiOff);
      expect(lobby.joinCalls, 0);
      await cubit.openSettings(wifiOff);
      expect(access.openedSettings, ['wifi']);
    });

    test('iOS: пояснение, «Продолжить» запоминает его и начинает поиск', () async {
      access.asksLocalNetworkPermission = true;
      final cubit = makeCubit();
      final explainer = await cubit.stream.firstWhere((state) => state is FindGamesUnavailable);
      expect((explainer as FindGamesUnavailable).problem, NetworkProblem.localNetworkExplainer);

      final searching = cubit.stream.firstWhere((state) => state is FindGamesSearching);
      await cubit.continueAfterExplainer();
      await searching;
      await hostGame(gameName: 'Цири', playerName: 'Цири');

      await cubit.stream.firstWhere((state) => state is FindGamesSearching && state.games.isNotEmpty);
      expect(settings.saved.localNetworkExplained, isTrue);
    });

    test('iOS: служба поиска отказала после пояснения — доступ к локальной сети запрещён', () async {
      access.asksLocalNetworkPermission = true;
      await settings.save(const AppSettings(localNetworkExplained: true));
      final cubit = makeCubit();
      await cubit.stream.firstWhere((state) => state is FindGamesSearching && state.games.isEmpty);

      lobby.failDiscover();

      final unavailable = await cubit.stream.firstWhere((state) => state is FindGamesUnavailable);
      expect((unavailable as FindGamesUnavailable).problem, NetworkProblem.localNetworkDenied);
    });

    group('по QR-коду', () {
      Future<GameAddress> hostAddress() async {
        final host = ((await hostGame(gameName: 'Цири', playerName: 'Цири')) as NetworkGameOpened).game;
        return (await host.address())!;
      }

      test('адрес из кода ведёт в комнату хоста, объявления гость не видел', () async {
        final address = await hostAddress();
        final cubit = makeCubit();
        await cubit.stream.firstWhere((state) => state is FindGamesSearching);

        await cubit.joinByCode(GameInvite.decode(GameInvite.encode(address))!);

        expect(cubit.state, isA<FindGamesJoined>());
        await settle();
        expect(hostActive.current?.room.opponent?.name, 'Гость');
      });

      test('хост недоступен: причина, «Повторить» подключается по тому же адресу', () async {
        final address = await hostAddress();
        final cubit = makeCubit();
        await cubit.stream.firstWhere((state) => state is FindGamesSearching);
        lobby.failJoins = 1;

        await cubit.joinByCode(address);
        expect(
          cubit.state,
          isA<FindGamesFailed>()
              .having((failed) => failed.result, 'result', isA<NetworkUnreachable>())
              .having((failed) => failed.address, 'address', address),
        );

        await cubit.retry();
        expect(cubit.state, isA<FindGamesJoined>());
      });

      test('Wi-Fi выключился после сканирования: подключения нет, причина названа', () async {
        final address = await hostAddress();
        final cubit = makeCubit();
        await cubit.stream.firstWhere((state) => state is FindGamesSearching);
        access.wifiOn = false;

        await cubit.joinByCode(address);

        expect(
          cubit.state,
          isA<FindGamesFailed>().having((failed) => failed.result, 'result', _unavailable(wifiOff)),
        );
        expect(lobby.joinCalls, 0);
      });
    });

    test('партию с чужой версией выбрать нельзя', () async {
      const foreign = GameAd(
        id: 'foreign',
        hostName: 'Эмиель',
        ruleset: Ruleset(id: 'x', hash: 'y', engineVersion: 1),
      );
      await lobby.host(foreign);
      final cubit = makeCubit();
      final found = await cubit.stream.firstWhere((state) => state is FindGamesSearching && state.games.isNotEmpty);

      await cubit.join((found as FindGamesSearching).games.single);

      expect(cubit.state, isA<FindGamesSearching>());
      expect(lobby.joinCalls, 0);
    });
  });

  group('QR-код хоста', () {
    Future<NetworkGame> hosted() async =>
        ((await hostGame(gameName: 'Цири', playerName: 'Цири')) as NetworkGameOpened).game;

    HostInviteCubit makeCubit(NetworkGame game) {
      final cubit = HostInviteCubit(game);
      addTearDown(cubit.close);
      return cubit;
    }

    test('код несёт приглашение с адресом партии, под ним адрес для людей', () async {
      final game = await hosted();

      final cubit = makeCubit(game);
      final ready = await cubit.stream.firstWhere((state) => state is HostInviteReady) as HostInviteReady;

      expect(GameInvite.decode(ready.invite), await game.address());
      expect(ready.label, '10.0.0.2:4000');
    });

    test('адрес IPv6 в подписи берётся в скобки', () async {
      final game = await hosted();
      lobby.hosted.values.single.hosts = const ['fe80::1'];

      final cubit = makeCubit(game);
      final ready = await cubit.stream.firstWhere((state) => state is HostInviteReady) as HostInviteReady;

      expect(ready.label, '[fe80::1]:4000');
    });

    test('соперник подключился: код больше не нужен', () async {
      final game = await hosted();
      final cubit = makeCubit(game);
      await cubit.stream.firstWhere((state) => state is HostInviteReady);

      final done = cubit.stream.firstWhere((state) => state is HostInviteDone);
      final found = (await discover().firstWhere((games) => games.isNotEmpty)).single;
      await joinGame(found: found.found, playerName: 'Вереск');
      await settle();

      await done;
    });

    test('соперник подключился, пока открывался экран: код не показывается', () async {
      final game = await hosted();
      final found = (await discover().firstWhere((games) => games.isNotEmpty)).single;
      await joinGame(found: found.found, playerName: 'Вереск');
      await settle();

      final cubit = makeCubit(game);

      expect(cubit.state, isA<HostInviteDone>());
    });

    test('партия закрыта: адреса нет, показывать нечего', () async {
      final game = await hosted();
      await game.close();

      final cubit = makeCubit(game);

      await cubit.stream.firstWhere((state) => state is HostInviteFailed || state is HostInviteDone);
    });
  });

  group('комната', () {
    /// Хост и гость в комнате; возвращает держатель хоста.
    Future<(RoomCubit, NetworkGame, NetworkGame)> room() async {
      final host = ((await hostGame(gameName: 'Цири', playerName: 'Цири')) as NetworkGameOpened).game;
      final found = (await discover().firstWhere((games) => games.isNotEmpty)).single;
      final guest = ((await joinGame(found: found.found, playerName: 'Вереск')) as NetworkGameOpened).game;
      await settle();
      final cubit = RoomCubit(host, loadRules, GetDeck(decks), tick: const Duration(milliseconds: 5));
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((state) => state.rules != null);
      return (cubit, host, guest);
    }

    test('выбранная колода проверяется по правилам и сообщается сопернику вместе с лидером', () async {
      final (cubit, _, guest) = await room();

      await cubit.selectDeck('north');
      await settle();

      expect(cubit.state.deck?.id, 'north');
      expect(cubit.state.deckValid, isTrue);
      expect(cubit.state.room.myStage, LobbyStage.chosen);
      expect(guest.room.opponent?.stage, LobbyStage.chosen);
      expect(guest.room.opponent?.leader, engine.LeaderId((await decks.findById('north'))!.leaderId));
    });

    test('колода, нарушающая правила, выбирается, но «готов» ей закрыт', () async {
      final (cubit, _, guest) = await room();

      await cubit.selectDeck('monsters');
      cubit.ready();
      await settle();

      expect(cubit.state.deck?.id, 'monsters');
      expect(cubit.state.issues, isNotEmpty);
      expect(cubit.state.room.myStage, LobbyStage.chosen);
      expect(guest.room.opponent?.stage, LobbyStage.chosen);
    });

    test('готовность и её отмена доходят до соперника', () async {
      final (cubit, _, guest) = await room();
      await cubit.selectDeck('north');

      cubit.ready();
      await settle();
      expect(cubit.state.room.myStage, LobbyStage.ready);
      expect(guest.room.opponent?.stage, LobbyStage.ready);

      cubit.cancelReady();
      await settle();
      expect(cubit.state.room.myStage, LobbyStage.chosen);
      expect(guest.room.opponent?.stage, LobbyStage.chosen);
    });

    test('переход в конструктор отменяет готовность, возврат без колоды возвращает прежнюю', () async {
      final (cubit, _, guest) = await room();
      await cubit.selectDeck('north');
      cubit.ready();
      await settle();

      cubit.startEditing(building: true);
      await settle();
      expect(guest.room.opponent?.stage, LobbyStage.building);

      await cubit.finishEditing(null);
      await settle();
      expect(cubit.state.room.myStage, LobbyStage.chosen);
      expect(guest.room.opponent?.stage, LobbyStage.chosen);
    });

    test('возврат из конструктора с новой колодой выбирает её', () async {
      final (cubit, _, guest) = await room();

      cubit.startEditing(building: true);
      await cubit.finishEditing('north');
      await settle();

      expect(cubit.state.deck?.id, 'north');
      expect(guest.room.opponent?.stage, LobbyStage.chosen);
    });

    test('когда готовы оба, отсчёт убывает по секундам и обрывается отменой готовности', () async {
      final (cubit, _, guest) = await room();
      await cubit.selectDeck('north');
      final seen = <int?>[];
      final subscription = cubit.stream.listen((state) => seen.add(state.countdownLeft));
      addTearDown(subscription.cancel);

      cubit.ready();
      guest.ready((await decks.findById('north'))!.toEngineDeck());
      await settle();
      await scheduler.elapse(const Duration(milliseconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(seen, containsAllInOrder([3, 2, 1]));

      guest.cancelReady();
      await settle();
      expect(cubit.state.countdownLeft, isNull);
    });

    test('уход с экрана до начала партии покидает игру, а после начала не трогает её', () async {
      final (cubit, host, _) = await room();

      await cubit.close();
      await settle();

      expect(host.isClosed, isTrue);
    });
  });

  group('связь в партии', () {
    Future<(NetworkGame, NetworkGame)> pair() async {
      final host = ((await hostGame(gameName: 'Цири', playerName: 'Цири')) as NetworkGameOpened).game;
      final found = (await discover().firstWhere((games) => games.isNotEmpty)).single;
      final guest = ((await joinGame(found: found.found, playerName: 'Вереск')) as NetworkGameOpened).game;
      await settle();
      return (host, guest);
    }

    MatchConnectionCubit connection(NetworkGame game) {
      final cubit = MatchConnectionCubit(game, tick: const Duration(milliseconds: 5));
      addTearDown(cubit.close);
      return cubit;
    }

    test('пока все на связи, окна нет', () async {
      final (host, guest) = await pair();

      expect(connection(host).state, const MatchConnectionState(isHost: true));
      expect(connection(guest).state, const MatchConnectionState(isHost: false));
    });

    test('хост: гость пропал, идёт отсчёт ожидания, «Ждать» закрывает окно, возвращение сбрасывает всё', () async {
      final (host, _) = await pair();
      final cubit = connection(host);
      lobby.failJoins = 1000;

      final lost = cubit.stream.firstWhere((state) => state.lost);
      await lobby.hostEnds.single.close();
      await settle();
      expect((await lost).left, host.reconnectWindow);
      final counting = await cubit.stream.firstWhere((state) => state.left < host.reconnectWindow);
      expect(counting.dismissed, isFalse);

      cubit.wait();
      expect(cubit.state.dismissed, isTrue);
      expect(cubit.state.lost, isTrue);

      lobby.failJoins = 0;
      final back = cubit.stream.firstWhere((state) => !state.lost);
      await scheduler.elapse(const Duration(seconds: 3));
      await settle();
      expect(await back, const MatchConnectionState(isHost: true));
    });

    test('гость: хост пропал, гость переподключается и по возвращении окно пропадает', () async {
      final (_, guest) = await pair();
      final cubit = connection(guest);
      lobby.failJoins = 1000;

      final lost = cubit.stream.firstWhere((state) => state.lost);
      await lobby.hostEnds.single.close();
      await settle();
      expect((await lost).isHost, isFalse);

      lobby.failJoins = 0;
      final back = cubit.stream.firstWhere((state) => !state.lost);
      await scheduler.elapse(const Duration(seconds: 3));
      await settle();
      await back;
      expect(cubit.state.lost, isFalse);
    });

    test('молчание гостя дольше 5 с: у хоста и гостя «нестабильно», когда кадры идут, пропадает', () async {
      lobby.faultScheduler = scheduler;
      final (host, guest) = await pair();
      final hostCubit = connection(host);
      final guestCubit = connection(guest);

      lobby.guestLinks.single.faults = const Faults(drop: 1);
      await scheduler.elapse(const Duration(seconds: 6));
      await settle();

      expect(hostCubit.state.unstable, isTrue);
      expect(hostCubit.state.lost, isFalse);
      expect(guestCubit.state.unstable, isTrue);
      expect(guestCubit.state.lost, isFalse);

      lobby.guestLinks.single.faults = Faults.none;
      await scheduler.elapse(const Duration(seconds: 3));
      await settle();

      expect(hostCubit.state, const MatchConnectionState(isHost: true));
      expect(guestCubit.state, const MatchConnectionState(isHost: false));
    });

    test('хост свернул приложение: гость видит окно «пауза», у хоста его нет, возвращение его убирает', () async {
      final (host, guest) = await pair();
      final hostCubit = connection(host);
      final guestCubit = connection(guest);

      host.setAway(away: true);
      await settle();
      expect(guestCubit.state.away, isTrue);
      expect(guestCubit.state.lost, isFalse);
      expect(hostCubit.state.away, isFalse);

      guestCubit.wait();
      expect(guestCubit.state.dismissed, isTrue);

      host.setAway(away: false);
      await settle();
      expect(guestCubit.state, const MatchConnectionState(isHost: false));
    });

    test('обрыв связи важнее «свернул приложение»: при потере хоста гость видит окно обрыва', () async {
      final (host, guest) = await pair();
      final cubit = connection(guest);
      host.setAway(away: true);
      await settle();
      expect(cubit.state.away, isTrue);
      lobby.failJoins = 1000;

      await lobby.hostEnds.single.close();
      await settle();

      expect(cubit.state.lost, isTrue);
      expect(cubit.state.away, isFalse);
      expect(cubit.state.dismissed, isFalse);
    });
  });
}
