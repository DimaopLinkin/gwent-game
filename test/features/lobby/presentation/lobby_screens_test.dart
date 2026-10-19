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
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_screen.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_screen.dart';
import 'package:gwent/src/features/lobby/presentation/lobby_deck_picker_screen.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_layer.dart';
import 'package:gwent/src/features/lobby/presentation/play_method_screen.dart';
import 'package:gwent/src/features/lobby/presentation/room_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/room_screen.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent_engine/gwent_engine.dart' as engine;
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/match_fixtures.dart';
import '../../../support/screen_guards.dart';
import '../support/fake_game_lobby.dart';

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
  late JoinNetworkGame joinGame;
  late DiscoverNetworkGames discover;
  late LoadDeckRules loadRules;

  setUpAll(() async {
    await loadDesignFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    content = await loadBaseContent();
  });

  setUp(() {
    lobby = FakeGameLobby();
    scheduler = FakeScheduler();
    settings = InMemorySettingsRepository();
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
      var created = 0;
      var found = 0;
      var backs = 0;
      await tester.pumpWidget(
        localizedScreen(PlayMethodScreen(onCreate: () => created++, onFind: () => found++, onBack: () => backs++)),
      );

      expectNoFallbackTextStyle(tester);
      expectBackButtonAtEdge(tester);
      expect(find.text(l10n.netPlayTitle), findsOneWidget);
      expect(find.text(l10n.netMethodWifi), findsOneWidget);
      expect(find.text(l10n.netMethodSoon), findsOneWidget);

      await tester.tap(find.text(l10n.netCreateGame));
      await tester.tap(find.text(l10n.netFindGame));
      await tester.tap(find.bySemanticsLabel(l10n.setupBack));
      expect((created, found, backs), (1, 1, 1));
    });
  });

  group('создание игры', () {
    Future<void> pumpCreate(WidgetTester tester, {required VoidCallback onCreated}) async {
      useSmallPhone(tester);
      final cubit = CreateGameCubit(hostGame, WatchSettings(settings), fallbackName: 'Игрок');
      closeAfterTest(tester, cubit);
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: CreateGameScreen(onCreated: onCreated, onBack: () {}),
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
  });

  group('поиск игр', () {
    Future<void> pumpFind(WidgetTester tester, {VoidCallback? onJoined}) async {
      useSmallPhone(tester);
      final cubit = FindGamesCubit(discover, joinGame, WatchSettings(settings), fallbackName: 'Гость');
      closeAfterTest(tester, cubit);
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: FindGamesScreen(onJoined: onJoined ?? () {}, onBack: () {}),
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
    final picked = <String?>[];

    setUp(() {
      started = 0;
      left = 0;
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

      await tester.tap(find.bySemanticsLabel(l10n.setupBack));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.netLeaveTitle), findsOneWidget);
      expect(find.text(l10n.netLeaveBodyHost), findsOneWidget);
      expect(left, 0);
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

    /// Слой связи над игрой; возвращает держатель, чтобы тест остановил его отсчёт до конца теста.
    Future<MatchConnectionCubit> pumpLayer(WidgetTester tester, NetworkGame game) async {
      useSmallPhone(tester);
      final cubit = MatchConnectionCubit(game);
      await tester.pumpWidget(
        localizedScreen(
          BlocProvider.value(
            value: cubit,
            child: MatchConnectionLayer(onEnd: () {}),
          ),
        ),
      );
      return cubit;
    }

    testWidgets('связь в норме: только точка, окна нет', (tester) async {
      final (host, _) = await pair(tester);
      await pumpLayer(tester, host);

      expect(find.text(l10n.netLinkOk), findsOneWidget);
      expect(find.text(l10n.netLostTitle), findsNothing);
    });

    testWidgets('хост: гость пропал — окно с «Ждать» и «Завершить матч»; «Ждать» оставляет таймер в углу', (
      tester,
    ) async {
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
      expect(find.textContaining(l10n.netLinkLost), findsOneWidget);
      await stopCountdown(tester, cubit);
    });

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
  });
}
