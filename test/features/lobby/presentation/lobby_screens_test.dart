import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/application/delete_deck.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/application/get_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_cubit.dart';
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
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_screen.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_screen.dart';
import 'package:gwent/src/features/lobby/presentation/host_invite_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/host_qr_screen.dart';
import 'package:gwent/src/features/lobby/presentation/lobby_deck_picker_screen.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_indicator.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_layer.dart';
import 'package:gwent/src/features/lobby/presentation/play_method_screen.dart';
import 'package:gwent/src/features/lobby/presentation/qr_scan_screen.dart';
import 'package:gwent/src/features/lobby/presentation/room_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/room_screen.dart';
import 'package:gwent/src/features/lobby/presentation/room_widgets.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent_engine/gwent_engine.dart' as engine;
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/match_fixtures.dart';
import '../../../support/screen_guards.dart';
import '../support/fake_game_lobby.dart';
import '../support/lobby_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late AppLocalizations l10n;
  late FakeGameLobby lobby;
  late FakeScheduler scheduler;
  late InMemorySettingsRepository settings;
  late InMemoryDeckRepository decks;
  late ActiveNetworkGame hostActive;
  late ActiveNetworkGame guestActive;
  late HostNetworkGame hostGame;
  late HostNetworkGame admittingGame;
  late JoinNetworkGame joinGame;
  late DiscoverNetworkGames discover;
  late LoadDeckRules loadRules;
  late FakeNetworkAccess access;
  late NetworkReadiness readiness;

  setUpAll(() async {
    await loadDesignFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    content = await loadBaseContent();
  });

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
    hostGame = HostNetworkGame(setup, lobby, hostActive, SecureEntropy(), scheduler, requireAdmission: false);
    admittingGame = HostNetworkGame(setup, lobby, hostActive, SecureEntropy(), scheduler);
    joinGame = JoinNetworkGame(setup, lobby, guestActive, scheduler);
    discover = DiscoverNetworkGames(setup, lobby);
    loadRules = LoadDeckRules(GameContentDeckRulesSource(loadContent));
  });

  /// Размер телефона и закрытие игр после теста: сетевой код живёт на настоящих часах, поэтому закрываем вне фальшивых.
  void useSmallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(
      () => tester.runAsync(() async {
        await hostActive.current?.close();
        await guestActive.current?.close();
      }),
    );
  }

  /// Закрывает держатель после теста. Остановка потока поиска ждёт микрозадач в фальшивых часах теста, поэтому их
  /// крутят `pump`ом, пока закрытие не закончится.
  void closeAfterTest(WidgetTester tester, BlocBase<Object?> cubit) => addTearDown(() async {
    var done = false;
    final closing = cubit.close().whenComplete(() => done = true);
    for (var i = 0; i < 20 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await closing;
  });

  /// Ждёт, пока сетевой код, живущий на настоящих часах, ответит, и показывает результат.
  Future<void> settleNetwork(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() async {
        await scheduler.flush();
        await Future<void>.delayed(const Duration(milliseconds: 5));
      });
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  group('выбор способа', () {
    testWidgets('Wi-Fi доступен, Bluetooth «скоро»; кнопки ведут к созданию и поиску, «назад» у края', (tester) async {
      useSmallPhone(tester);
      final created = <PlayMethod>[];
      final found = <PlayMethod>[];
      var backs = 0;
      await tester.pumpWidget(
        localizedScreen(PlayMethodScreen(onCreate: created.add, onFind: found.add, onBack: () => backs++)),
      );

      expectNoFallbackTextStyle(tester);
      expectBackButtonAtEdge(tester);
      expect(find.text(l10n.netPlayTitle), findsOneWidget);
      expect(find.text(l10n.netMethodWifi), findsOneWidget);
      expect(find.text(l10n.netMethodSoon), findsOneWidget);

      await tester.tap(find.text(l10n.netCreateGame));
      await tester.tap(find.text(l10n.netFindGame));
      await tester.tap(find.bySemanticsLabel(l10n.setupBack));
      expect(created, [PlayMethod.wifi]);
      expect(found, [PlayMethod.wifi]);
      expect(backs, 1);
    });
  });

  group('создание игры', () {
    Future<void> pumpCreate(
      WidgetTester tester, {
      required VoidCallback onCreated,
      VoidCallback? onBack,
    }) async {
      useSmallPhone(tester);
      final cubit = CreateGameCubit(hostGame, WatchSettings(settings), readiness, fallbackName: 'Игрок');
      closeAfterTest(tester, cubit);
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: CreateGameScreen(onCreated: onCreated, onBack: onBack ?? () {}),
          ),
        ),
      );
      await settleNetwork(tester);
    }

    testWidgets('в поле имя по умолчанию; «Создать» объявляет партию и сообщает экрану', (tester) async {
      var created = 0;
      await pumpCreate(tester, onCreated: () => created++);

      expectNoFallbackTextStyle(tester);
      expectBackButtonAtEdge(tester);
      expect(find.text(l10n.netCreateNameLabel), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Игрок');

      await tester.enterText(find.byType(TextField), 'Ночной Гвинт');
      await tester.tap(find.text(l10n.netCreateSubmit));
      await settleNetwork(tester);

      expect(created, 1);
      expect(lobby.hosted.values.single.ad.hostName, 'Ночной Гвинт');
    });

    testWidgets('сеть недоступна: причина и «Повторить»', (tester) async {
      var created = 0;
      await pumpCreate(tester, onCreated: () => created++);
      lobby.failHost = true;

      await tester.tap(find.text(l10n.netCreateSubmit));
      await settleNetwork(tester);
      expect(find.text(l10n.netNoticeUnavailableTitle), findsOneWidget);
      expect(created, 0);

      await tester.tap(find.text(l10n.netNoticeRetry));
      await settleNetwork(tester);
      expect(created, 1);
    });

    testWidgets('Wi-Fi выключен (7c): пояснение, «Открыть настройки» ведёт в настройки Wi-Fi', (tester) async {
      var backs = 0;
      access.wifiOn = false;
      await pumpCreate(tester, onCreated: () {}, onBack: () => backs++);

      await tester.tap(find.text(l10n.netCreateSubmit));
      await settleNetwork(tester);
      expect(find.text(l10n.netProblemWifiTitle), findsOneWidget);
      expect(find.text(l10n.netProblemWifiText), findsOneWidget);
      expect(find.text(l10n.netProblemExplainStep1), findsNothing);
      expectNoFallbackTextStyle(tester);

      await tester.tap(find.text(l10n.netProblemSettings));
      expect(access.openedSettings, ['wifi']);
      await tester.tap(find.text(l10n.netNoticeBack));
      expect(backs, 1);
      expect(lobby.hosted, isEmpty);
    });

    testWidgets('iOS, первый раз (7d): шаги пояснения, «Продолжить» создаёт партию', (tester) async {
      var created = 0;
      access.asksLocalNetworkPermission = true;
      await pumpCreate(tester, onCreated: () => created++);

      await tester.tap(find.text(l10n.netCreateSubmit));
      await settleNetwork(tester);
      expect(find.text(l10n.netProblemExplainTitle), findsOneWidget);
      expect(find.text(l10n.netProblemExplainStep1), findsOneWidget);
      expect(find.text(l10n.netProblemExplainStep2), findsOneWidget);
      expect(find.text(l10n.netProblemExplainStep3), findsOneWidget);
      expect(find.text(l10n.netProblemLater), findsOneWidget);
      expectNoFallbackTextStyle(tester);

      await tester.tap(find.text(l10n.netProblemContinue));
      await settleNetwork(tester);

      expect(created, 1);
      expect(settings.saved.localNetworkExplained, isTrue);
    });

    testWidgets('iOS запретила локальную сеть (7e): инструкция и «Открыть настройки» ведёт в настройки игры', (
      tester,
    ) async {
      access.asksLocalNetworkPermission = true;
      await settings.save(const AppSettings(localNetworkExplained: true));
      await pumpCreate(tester, onCreated: () {});
      lobby.failHost = true;

      await tester.tap(find.text(l10n.netCreateSubmit));
      await settleNetwork(tester);

      expect(find.text(l10n.netProblemDeniedTitle), findsOneWidget);
      expect(find.text(l10n.netProblemDeniedStep1), findsOneWidget);
      expect(find.text(l10n.netProblemDeniedStep3), findsOneWidget);
      await tester.tap(find.text(l10n.netProblemSettings));
      expect(access.openedSettings, ['app']);
    });
  });

  group('поиск игр', () {
    GameAddress? scanned;

    setUp(() => scanned = null);

    Future<void> pumpFind(WidgetTester tester, {VoidCallback? onJoined}) async {
      useSmallPhone(tester);
      final cubit = FindGamesCubit(discover, joinGame, WatchSettings(settings), readiness, fallbackName: 'Гость');
      closeAfterTest(tester, cubit);
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: FindGamesScreen(onJoined: onJoined ?? () {}, onScan: () async => scanned, onBack: () {}),
          ),
        ),
      );
      await settleNetwork(tester);
    }

    testWidgets('пока партий нет, экран ищет; найденная партия появляется сама, «Войти» подключает гостя', (
      tester,
    ) async {
      var joined = 0;
      await pumpFind(tester, onJoined: () => joined++);
      expectNoFallbackTextStyle(tester);
      expectBackButtonAtEdge(tester);
      expect(find.text(l10n.netFindEmptyTitle), findsOneWidget);

      await tester.runAsync(() => hostGame(gameName: 'Цири', playerName: 'Цири'));
      await settleNetwork(tester);
      expect(find.text('Цири'), findsOneWidget);
      expect(find.text(l10n.netFindEmptyTitle), findsNothing);

      await tester.tap(find.text(l10n.netFindJoin));
      await settleNetwork(tester);

      expect(joined, 1);
      expect(guestActive.current, isNotNull);
    });

    testWidgets('партия с другим набором карт видна с причиной, а войти в неё нельзя', (tester) async {
      await pumpFind(tester);
      await tester.runAsync(
        () => lobby.host(
          const GameAd(
            id: 'foreign',
            hostName: 'Эмиель',
            ruleset: Ruleset(id: 'other', hash: 'sha256:0', engineVersion: 1),
          ),
        ),
      );
      await settleNetwork(tester);

      expect(find.text('Эмиель'), findsOneWidget);
      expect(find.text(l10n.netFindRulesetMismatch), findsOneWidget);
      expect(find.text(l10n.netFindJoin), findsNothing);
    });

    testWidgets('хост недоступен: причина «не удалось подключиться», «Повторить» подключает', (tester) async {
      var joined = 0;
      await tester.runAsync(() => hostGame(gameName: 'Цири', playerName: 'Цири'));
      await pumpFind(tester, onJoined: () => joined++);
      lobby.failJoins = 1;

      await tester.tap(find.text(l10n.netFindJoin));
      await settleNetwork(tester);
      expect(find.text(l10n.netNoticeFailTitle), findsOneWidget);

      await tester.tap(find.text(l10n.netNoticeRetry));
      await settleNetwork(tester);
      expect(joined, 1);
    });

    testWidgets('«Сканировать QR» открывает сканер, считанный адрес подключает гостя к хосту', (tester) async {
      var joined = 0;
      final host = await tester.runAsync(() => hostGame(gameName: 'Цири', playerName: 'Цири'));
      final game = (host! as NetworkGameOpened).game;
      scanned = await tester.runAsync<GameAddress?>(game.address);
      await pumpFind(tester, onJoined: () => joined++);

      await tester.tap(find.text(l10n.netScanButton));
      await settleNetwork(tester);

      expect(joined, 1);
      expect(guestActive.current, isNotNull);
    });

    testWidgets('сканер закрыт без кода: экран остаётся на поиске', (tester) async {
      await pumpFind(tester);

      await tester.tap(find.text(l10n.netScanButton));
      await settleNetwork(tester);

      expect(find.text(l10n.netFindEmptyTitle), findsOneWidget);
      expect(guestActive.current, isNull);
    });

    testWidgets('не удалось подключиться (7b): три кнопки, запасной путь — QR', (tester) async {
      await tester.runAsync(() => hostGame(gameName: 'Цири', playerName: 'Цири'));
      await pumpFind(tester);
      lobby.failJoins = 1;

      await tester.tap(find.text(l10n.netFindJoin));
      await settleNetwork(tester);

      expect(find.text(l10n.netNoticeRetry), findsOneWidget);
      expect(find.text(l10n.netScanButton), findsOneWidget);
      expect(find.text(l10n.netNoticeBack), findsOneWidget);
    });

    testWidgets('Wi-Fi выключен (7c): поиск не идёт, «Открыть настройки» открывает настройки Wi-Fi', (tester) async {
      access.wifiOn = false;
      await pumpFind(tester);

      expect(find.text(l10n.netProblemWifiTitle), findsOneWidget);
      expect(find.text(l10n.netScanButton), findsNothing);
      expectNoFallbackTextStyle(tester);

      await tester.tap(find.text(l10n.netProblemSettings));
      expect(access.openedSettings, ['wifi']);
    });

    testWidgets('iOS, первый раз (7d): «Продолжить» запоминает пояснение и начинает поиск', (tester) async {
      access.asksLocalNetworkPermission = true;
      await pumpFind(tester);
      expect(find.text(l10n.netProblemExplainTitle), findsOneWidget);

      await tester.tap(find.text(l10n.netProblemContinue));
      await settleNetwork(tester);

      expect(find.text(l10n.netFindEmptyTitle), findsOneWidget);
      expect(settings.saved.localNetworkExplained, isTrue);
    });

    testWidgets('iOS запретила локальную сеть (7e): поиск отказал, показана инструкция', (tester) async {
      access.asksLocalNetworkPermission = true;
      await settings.save(const AppSettings(localNetworkExplained: true));
      await pumpFind(tester);

      lobby.failDiscover();
      await settleNetwork(tester);

      expect(find.text(l10n.netProblemDeniedTitle), findsOneWidget);
      expect(find.text(l10n.netProblemDeniedStep2), findsOneWidget);
    });

    testWidgets('служба поиска отказала: сеть недоступна, «Повторить» ищет заново', (tester) async {
      await pumpFind(tester);

      lobby.failDiscover();
      await settleNetwork(tester);
      expect(find.text(l10n.netNoticeUnavailableTitle), findsOneWidget);

      await tester.tap(find.text(l10n.netNoticeRetry));
      await settleNetwork(tester);
      expect(find.text(l10n.netFindEmptyTitle), findsOneWidget);
    });
  });

  group('комната', () {
    var started = 0;
    var left = 0;
    var qrShown = 0;
    final picked = <String?>[];

    setUp(() {
      started = 0;
      left = 0;
      qrShown = 0;
      picked.clear();
    });

    Future<RoomCubit> pumpRoom(
      WidgetTester tester, {
      required NetworkGame game,
      String? pickDeck,
      String? buildDeck,
    }) async {
      useSmallPhone(tester);
      final cubit = RoomCubit(game, loadRules, GetDeck(decks), tick: const Duration(milliseconds: 5));
      closeAfterTest(tester, cubit);
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: RoomScreen(
              isHost: game.isHost,
              title: game.title ?? '',
              onPickDeck: (current) async {
                picked.add(current);
                return pickDeck;
              },
              onBuildDeck: (deckId) async => buildDeck,
              onShowQr: () => qrShown++,
              onStarted: () => started++,
              onLeft: () => left++,
            ),
          ),
        ),
      );
      await settleNetwork(tester);
      return cubit;
    }

    Future<NetworkGame> hosted(WidgetTester tester) async {
      final opened = await tester.runAsync(() => hostGame(gameName: 'Цири', playerName: 'Цири'));
      return (opened! as NetworkGameOpened).game;
    }

    Future<(NetworkGame, NetworkGame)> pair(WidgetTester tester) async {
      final host = await hosted(tester);
      final found = (await tester.runAsync(() => discover().firstWhere((games) => games.isNotEmpty)))!.single;
      final guest =
          ((await tester.runAsync(() => joinGame(found: found.found, playerName: 'Вереск')))! as NetworkGameOpened)
              .game;
      await settleNetwork(tester);
      return (host, guest);
    }

    testWidgets('хост ждёт соперника: название партии, способ, «Покинуть» спрашивает подтверждение', (tester) async {
      final host = await hosted(tester);
      await pumpRoom(tester, game: host);

      expectNoFallbackTextStyle(tester);
      expect(find.text(l10n.netWaitTitle), findsOneWidget);
      expect(find.text('Цири'), findsOneWidget);

      await tester.tap(find.text(l10n.netQrShow));
      expect(qrShown, 1);

      await tester.tap(find.bySemanticsLabel(l10n.setupBack));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.netLeaveTitle), findsOneWidget);
      expect(find.text(l10n.netLeaveBodyHost), findsOneWidget);
      expect(left, 0);
    });

    testWidgets('гость стучится: хост видит «Принять игрока», «Принять» пускает его в лобби', (tester) async {
      final opened = await tester.runAsync(() => admittingGame(gameName: 'Цири', playerName: 'Цири'));
      final host = (opened! as NetworkGameOpened).game;
      await pumpRoom(tester, game: host);
      final found = (await tester.runAsync(() => discover().firstWhere((games) => games.isNotEmpty)))!.single;
      await tester.runAsync(() => joinGame(found: found.found, playerName: 'Вереск'));
      await settleNetwork(tester);

      expectNoFallbackTextStyle(tester);
      expect(find.text(l10n.netAdmitTitle('Вереск')), findsOneWidget);
      expect(find.text(l10n.netAdmitBody), findsOneWidget);

      await tester.tap(find.text(l10n.netAdmitAccept));
      await settleNetwork(tester);

      expect(find.text(l10n.netAdmitTitle('Вереск')), findsNothing);
      expect(host.room.opponent?.name, 'Вереск');
    });

    testWidgets('«Отклонить» убирает запрос, гость получает отказ', (tester) async {
      final opened = await tester.runAsync(() => admittingGame(gameName: 'Цири', playerName: 'Цири'));
      final host = (opened! as NetworkGameOpened).game;
      await pumpRoom(tester, game: host);
      final found = (await tester.runAsync(() => discover().firstWhere((games) => games.isNotEmpty)))!.single;
      final joined = await tester.runAsync(() => joinGame(found: found.found, playerName: 'Вереск'));
      final guest = (joined! as NetworkGameOpened).game;
      await settleNetwork(tester);

      await tester.tap(find.text(l10n.netAdmitDecline));
      await settleNetwork(tester);

      expect(find.text(l10n.netAdmitTitle('Вереск')), findsNothing);
      expect(host.room.opponent, isNull);
      expect(guest.room.end, const RoomRefused(JoinRefusal.declined));
    });

    testWidgets('гость ждёт решения хоста: подпись ожидания, затем отказ с пояснением', (tester) async {
      final opened = await tester.runAsync(() => admittingGame(gameName: 'Цири', playerName: 'Цири'));
      final host = (opened! as NetworkGameOpened).game;
      final found = (await tester.runAsync(() => discover().firstWhere((games) => games.isNotEmpty)))!.single;
      final joined = await tester.runAsync(() => joinGame(found: found.found, playerName: 'Вереск'));
      final guest = (joined! as NetworkGameOpened).game;
      await pumpRoom(tester, game: guest);

      expect(find.text(l10n.netGuestWaiting), findsOneWidget);

      host.declineGuest();
      await settleNetwork(tester);

      expect(find.text(l10n.netNoticeDeclinedTitle), findsOneWidget);
    });

    testWidgets('подтверждённый уход закрывает игру и возвращает на прежний экран', (tester) async {
      final host = await hosted(tester);
      await pumpRoom(tester, game: host);

      await tester.tap(find.bySemanticsLabel(l10n.setupBack));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(l10n.netLeaveConfirm));
      await settleNetwork(tester);

      expect(left, 1);
      expect(host.isClosed, isTrue);
    });

    testWidgets('соперник подключился: обе карточки, колоды нет, «Готов» закрыт', (tester) async {
      final (host, _) = await pair(tester);
      await pumpRoom(tester, game: host);

      expectNoFallbackTextStyle(tester);
      expectBackButtonAtEdge(tester);
      expect(find.text('Вереск'), findsOneWidget);
      expect(find.text(l10n.netNoDeck), findsOneWidget);
      expect(tester.widget<GwentButton>(find.widgetWithText(GwentButton, l10n.netReady)).onPressed, isNull);
      expect(find.text(l10n.netPickDeckHint), findsOneWidget);
    });

    testWidgets('выбор колоды: экран выбора открывается, выбранная колода показана, «Готов» отмечает готовность', (
      tester,
    ) async {
      final (host, guest) = await pair(tester);
      await pumpRoom(tester, game: host, pickDeck: 'north');

      await tester.tap(find.text(l10n.netDeckPick));
      await settleNetwork(tester);
      expect(picked, [null]);
      expect(find.text(l10n.netNoDeck), findsNothing);
      expect(guest.room.opponent?.stage, LobbyStage.chosen);

      await tester.tap(find.widgetWithText(GwentButton, l10n.netReady));
      await settleNetwork(tester);
      expect(host.room.myStage, LobbyStage.ready);
      expect(guest.room.opponent?.stage, LobbyStage.ready);
      expect(find.text(l10n.netReadyCancel), findsOneWidget);
    });

    testWidgets('фракцию и лидера соперника в лобби не показывают, свои показывают', (tester) async {
      final (host, guest) = await pair(tester);
      await pumpRoom(tester, game: host, pickDeck: 'north');
      await tester.tap(find.text(l10n.netDeckPick));
      await settleNetwork(tester);

      guest.ready((await decks.findById('north'))!.toEngineDeck());
      await settleNetwork(tester);

      expect(host.room.opponent?.leader, isNotNull, reason: 'лидер соперника дошёл до экрана');
      final opponentCard = find.byType(RoomPlayerCard).first;
      final myCard = find.byType(RoomPlayerCard).last;
      expect(find.descendant(of: opponentCard, matching: find.text(l10n.netOpponentSecret)), findsOneWidget);
      expect(find.descendant(of: opponentCard, matching: find.textContaining('Фольтест')), findsNothing);
      expect(find.descendant(of: myCard, matching: find.textContaining('Фольтест')), findsOneWidget);
    });

    testWidgets('колода, нарушающая правила, показана с причиной, и «Готов» ей закрыт', (tester) async {
      final (host, _) = await pair(tester);
      await pumpRoom(tester, game: host, pickDeck: 'monsters');

      await tester.tap(find.text(l10n.netDeckPick));
      await settleNetwork(tester);

      expect(tester.widget<GwentButton>(find.widgetWithText(GwentButton, l10n.netReady)).onPressed, isNull);
      expect(find.text(l10n.netPickDeckHint), findsNothing);
    });

    testWidgets('когда готовы оба, идёт отсчёт, а по его концу экран сообщает о начале партии', (tester) async {
      final (host, guest) = await pair(tester);
      await pumpRoom(tester, game: host, pickDeck: 'north');
      await tester.tap(find.text(l10n.netDeckPick));
      await settleNetwork(tester);
      await tester.tap(find.widgetWithText(GwentButton, l10n.netReady));
      await settleNetwork(tester);

      guest.ready((await decks.findById('north'))!.toEngineDeck());
      await settleNetwork(tester);
      expect(find.text(l10n.netCountdownTitle), findsOneWidget);

      await tester.runAsync(() => scheduler.elapse(const Duration(seconds: 3)));
      await settleNetwork(tester);
      expect(started, 1);
    });

    testWidgets('хост закрыл партию: гость видит причину и возвращается кнопкой', (tester) async {
      final (host, guest) = await pair(tester);
      await pumpRoom(tester, game: guest);

      await tester.runAsync(host.leave);
      await settleNetwork(tester);

      expect(find.text(l10n.netNoticeClosedTitle), findsOneWidget);
      await tester.tap(find.text(l10n.netNoticeBack));
      expect(left, 1);
    });
  });

  group('выбор колоды для лобби', () {
    testWidgets('показывает колоды, выбранную отмечает; «Выбрать» отдаёт её, «Собрать новую» открывает конструктор', (
      tester,
    ) async {
      useSmallPhone(tester);
      final cubit = DeckListCubit(WatchDecks(decks), loadRules, DeleteDeck(decks));
      closeAfterTest(tester, cubit);
      String? selected;
      var built = 0;
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: LobbyDeckPickerScreen(
              initialDeckId: 'north',
              onSelect: (id) => selected = id,
              onBuildNew: () => built++,
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));

      expectNoFallbackTextStyle(tester);
      expectBackButtonAtEdge(tester);
      expect(find.text(l10n.netPickerTitle), findsOneWidget);

      await tester.tap(find.text(l10n.netDeckPick));
      expect(selected, 'north');
      await tester.tap(find.text(l10n.netPickerNew));
      expect(built, 1);
    });
  });

  group('связь в партии', () {
    Future<(NetworkGame, NetworkGame)> pair(WidgetTester tester) async {
      final opened = await tester.runAsync(() => hostGame(gameName: 'Цири', playerName: 'Цири'));
      final host = (opened! as NetworkGameOpened).game;
      final found = (await tester.runAsync(() => discover().firstWhere((games) => games.isNotEmpty)))!.single;
      final guest =
          ((await tester.runAsync(() => joinGame(found: found.found, playerName: 'Вереск')))! as NetworkGameOpened)
              .game;
      await settleNetwork(tester);
      return (host, guest);
    }

    /// Останавливает отсчёт держателя: фальшивые часы теста не терпят висящих таймеров.
    Future<void> stopCountdown(WidgetTester tester, MatchConnectionCubit cubit) async {
      unawaited(cubit.close());
      await tester.pump();
    }

    /// Слой связи над игрой и индикатор в узком углу, как в полосе соперника; возвращает держатель, чтобы тест
    /// остановил его отсчёт до конца теста.
    Future<MatchConnectionCubit> pumpLayer(WidgetTester tester, NetworkGame game, {double statusWidth = 170}) async {
      useSmallPhone(tester);
      final cubit = MatchConnectionCubit(game);
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(left: 40, top: 20, width: statusWidth, child: const MatchConnectionIndicator()),
                MatchConnectionLayer(onEnd: () {}),
              ],
            ),
          ),
        ),
      );
      return cubit;
    }

    testWidgets('связь в норме: один значок без подписи, окна нет', (tester) async {
      final handle = tester.ensureSemantics();
      final (host, _) = await pair(tester);
      await pumpLayer(tester, host);

      expect(find.bySemanticsLabel(l10n.netLinkOk), findsOneWidget);
      expect(find.text(l10n.netLinkOk), findsNothing);
      expect(find.text(l10n.netLostTitle), findsNothing);
      handle.dispose();
    });

    testWidgets('связь в норме: слой не рисует ничего поверх поля', (tester) async {
      final (host, _) = await pair(tester);
      final cubit = MatchConnectionCubit(host);
      closeAfterTest(tester, cubit);
      useSmallPhone(tester);
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: MatchConnectionLayer(onEnd: () {}),
          ),
        ),
      );

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('хост: гость пропал — окно с «Ждать» и «Завершить матч»; «Ждать» оставляет таймер в индикаторе', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final (host, _) = await pair(tester);
      final cubit = await pumpLayer(tester, host);
      lobby.failJoins = 1000;

      await tester.runAsync(() => lobby.hostEnds.single.close());
      await settleNetwork(tester);
      expect(find.text(l10n.netLostTitle), findsOneWidget);
      expect(find.text(l10n.netLostWait), findsOneWidget);
      expect(find.text(l10n.netLostEnd), findsOneWidget);
      expect(find.text('2:00'), findsWidgets);

      await tester.tap(find.text(l10n.netLostWait));
      await tester.pump();
      expect(find.text(l10n.netLostTitle), findsNothing);
      expect(find.bySemanticsLabel('${l10n.netLinkLost} · 2:00'), findsOneWidget);
      expect(find.text('${l10n.netLinkLost} · 2:00'), findsOneWidget);
      await stopCountdown(tester, cubit);
      handle.dispose();
    });

    testWidgets(
      'мало места: вместо «Нет связи · 2:00» остаётся «2:00», а совсем без места индикатор молчит, но читается диктором',
      (tester) async {
        final handle = tester.ensureSemantics();
        final (host, _) = await pair(tester);
        final cubit = await pumpLayer(tester, host, statusWidth: 70);
        lobby.failJoins = 1000;

        await tester.runAsync(() => lobby.hostEnds.single.close());
        await settleNetwork(tester);
        await tester.tap(find.text(l10n.netLostWait));
        await tester.pump();
        expect(find.text('${l10n.netLinkLost} · 2:00'), findsNothing);
        expect(find.text('2:00'), findsOneWidget);

        await tester.pumpWidget(
          localizedScreen(
            BlocProvider.value(
              value: cubit,
              child: const Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 20, child: MatchConnectionIndicator()),
              ),
            ),
          ),
        );
        expect(find.text('2:00'), findsNothing);
        expect(find.bySemanticsLabel('${l10n.netLinkLost} · 2:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await stopCountdown(tester, cubit);
        handle.dispose();
      },
    );

    testWidgets('гость: хост пропал — «Переподключаемся…» и одна кнопка «Завершить матч»', (tester) async {
      final (_, guest) = await pair(tester);
      final cubit = await pumpLayer(tester, guest);
      lobby.failJoins = 1000;

      await tester.runAsync(() => lobby.hostEnds.single.close());
      await settleNetwork(tester);

      expect(find.text(l10n.netReconnectTitle), findsOneWidget);
      expect(find.text(l10n.netLostWait), findsNothing);
      expect(find.text(l10n.netLostEnd), findsOneWidget);
      await stopCountdown(tester, cubit);
    });

    testWidgets('связь нестабильна: янтарная метка «Нестабильно» без окна', (tester) async {
      lobby.faultScheduler = scheduler;
      final (host, _) = await pair(tester);
      await pumpLayer(tester, host);

      lobby.guestLinks.single.faults = const Faults(drop: 1);
      await tester.runAsync(() => scheduler.elapse(const Duration(seconds: 6)));
      await settleNetwork(tester);

      expect(find.text(l10n.netLinkUnstable), findsOneWidget);
      expect(find.text(l10n.netLinkOk), findsNothing);
      expect(find.text(l10n.netLostTitle), findsNothing);
      expect(find.text(l10n.netAwayText), findsNothing);
    });

    testWidgets('гость: хост свернул приложение — окно «Партия на паузе», «Ждать» оставляет метку «Пауза»', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final (host, guest) = await pair(tester);
      final cubit = await pumpLayer(tester, guest);

      host.setAway(away: true);
      await settleNetwork(tester);
      expect(find.text(l10n.netAwayText), findsOneWidget);
      expect(find.text(l10n.netAwayTitle), findsOneWidget);
      expect(find.text(l10n.netLostWait), findsOneWidget);
      expect(find.text(l10n.netLostEnd), findsOneWidget);

      await tester.tap(find.text(l10n.netLostWait));
      await tester.pump();
      expect(find.text(l10n.netAwayText), findsNothing);
      expect(find.text(l10n.netLinkAway), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.netAwayTitle), findsOneWidget);

      host.setAway(away: false);
      await settleNetwork(tester);
      expect(find.text(l10n.netLinkAway), findsNothing);
      expect(find.bySemanticsLabel(l10n.netLinkOk), findsOneWidget);
      await stopCountdown(tester, cubit);
      handle.dispose();
    });
  });

  group('QR-код', () {
    Future<NetworkGame> hosted(WidgetTester tester) async {
      final opened = await tester.runAsync(() => hostGame(gameName: 'Цири', playerName: 'Цири'));
      return (opened! as NetworkGameOpened).game;
    }

    testWidgets('хост: код несёт приглашение, под ним адрес и подсказка; «Назад к ожиданию» возвращает', (
      tester,
    ) async {
      useSmallPhone(tester);
      final game = await hosted(tester);
      var backs = 0;
      final cubit = HostInviteCubit(game);
      closeAfterTest(tester, cubit);
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: HostQrScreen(onBack: () => backs++),
          ),
        ),
      );
      await settleNetwork(tester);

      expectNoFallbackTextStyle(tester);
      expectBackButtonAtEdge(tester);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(l10n.netQrCaption), findsOneWidget);
      expect(find.text('10.0.0.2:4000'), findsOneWidget);
      expect(find.text(l10n.netQrHint), findsOneWidget);

      await tester.tap(find.text(l10n.netQrBack));
      expect(backs, 1);
    });

    testWidgets('хост: соперник подключился — экран сам возвращается к комнате', (tester) async {
      useSmallPhone(tester);
      final game = await hosted(tester);
      var backs = 0;
      final cubit = HostInviteCubit(game);
      closeAfterTest(tester, cubit);
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: HostQrScreen(onBack: () => backs++),
          ),
        ),
      );
      await settleNetwork(tester);

      final found = (await tester.runAsync(() => discover().firstWhere((games) => games.isNotEmpty)))!.single;
      await tester.runAsync(() => joinGame(found: found.found, playerName: 'Вереск'));
      await settleNetwork(tester);

      expect(backs, 1);
    });

    group('сканер гостя', () {
      const invite = 'gwent://lan/abc?p=4000&h=10.0.0.2';
      late ValueChanged<String> emit;
      late VoidCallback breakCamera;
      final invited = <GameAddress>[];
      var settingsOpened = 0;
      var backs = 0;

      setUp(() {
        invited.clear();
        settingsOpened = 0;
        backs = 0;
      });

      Future<void> pumpScan(WidgetTester tester) async {
        useSmallPhone(tester);
        await tester.pumpWidget(
          localizedScreen(
            QrScanScreen(
              onInvite: invited.add,
              onOpenSettings: () => settingsOpened++,
              onBack: () => backs++,
              scannerBuilder: (context, {required onCode, required onUnavailable}) {
                emit = onCode;
                breakCamera = onUnavailable;
                return const ColoredBox(color: Color(0xFF000000));
              },
            ),
          ),
        );
      }

      testWidgets('подсказки, рамка у края и «назад» у края', (tester) async {
        await pumpScan(tester);

        expectNoFallbackTextStyle(tester);
        expectBackButtonAtEdge(tester);
        expect(find.text(l10n.netScanTitle), findsOneWidget);
        expect(find.text(l10n.netScanAim), findsOneWidget);
        expect(find.text(l10n.netScanHint), findsOneWidget);

        await tester.tap(find.bySemanticsLabel(l10n.setupBack));
        expect(backs, 1);
      });

      testWidgets('код партии отдаётся один раз, повторные считывания игнорируются', (tester) async {
        await pumpScan(tester);

        emit(invite);
        emit(invite);
        await tester.pump();

        expect(invited, [GameInvite.decode(invite)]);
      });

      testWidgets('чужой QR-код отвергается сообщением, а следующий верный код принимается', (tester) async {
        await pumpScan(tester);

        emit('https://example.com');
        await tester.pump();
        expect(find.text(l10n.netScanForeign), findsOneWidget);
        expect(find.text(l10n.netScanHint), findsNothing);
        expect(invited, isEmpty);

        emit(invite);
        await tester.pump();
        expect(invited, hasLength(1));
      });

      testWidgets('камера недоступна: объяснение и «Открыть настройки»', (tester) async {
        await pumpScan(tester);

        breakCamera();
        await tester.pump();

        expect(find.text(l10n.netScanDeniedTitle), findsOneWidget);
        expect(find.text(l10n.netScanAim), findsNothing);
        expectNoFallbackTextStyle(tester);
        await tester.tap(find.text(l10n.netProblemSettings));
        expect(settingsOpened, 1);
        await tester.tap(find.text(l10n.netNoticeBack));
        expect(backs, 1);
      });
    });
  });
}
