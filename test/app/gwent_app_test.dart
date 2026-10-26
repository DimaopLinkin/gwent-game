import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gwent/src/app/app_dependencies.dart';
import 'package:gwent/src/app/gwent_app.dart';
import 'package:gwent/src/app/router/app_routes.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/chevron_button.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_play_screen.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_topic_screen.dart';
import 'package:gwent/src/features/match/presentation/match_screen.dart';
import 'package:gwent/src/features/match/presentation/start/match_intro_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_toss_view.dart';
import 'package:gwent/src/features/menu/presentation/menu_backdrop.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/presentation/settings_screen.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';
import 'package:gwent/src/features/tutorial/presentation/first_match_screen.dart';
import 'package:gwent_content/gwent_content.dart';

import '../features/lobby/support/fake_game_lobby.dart';
import '../features/lobby/support/lobby_fakes.dart';
import '../support/factories.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryDeckRepository decks;
  late AppLocalizations l10n;

  setUpAll(loadDesignFonts);

  setUp(() async {
    decks = InMemoryDeckRepository();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  /// Поднимает приложение. Пакет карт читается из ассетов настоящим временем, поэтому ждём его вне фальшивых часов.
  /// При «уменьшить движение» заставка исчезает сразу, а свеча не мерцает: `pumpAndSettle` не зависает.
  Future<void> pumpApp(
    WidgetTester tester, {
    ContentSource? source,
    bool reduceMotion = true,
    bool settle = true,
    InMemorySettingsRepository? settings,
    RecordingSoundOutput? sound,
  }) async {
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GwentApp(
        dependencies: AppDependencies(
          contentSource: source ?? AssetContentSource.basePack(rootBundle),
          appInfo: const FakeAppInfo('1.2.3'),
          deckRepository: decks,
          collectionRepository: InMemoryCollectionRepository(),
          settingsRepository: settings ?? InMemorySettingsRepository(),
          matchHistoryRepository: InMemoryMatchHistoryRepository(),
          clock: FakeClock(DateTime.utc(2026, 10, 11)),
          idGenerator: SequentialIdGenerator(),
          seedGenerator: FixedSeedGenerator(1),
          gameLobby: FakeGameLobby(),
          onlineLobby: FakeGameLobby(),
          networkAccess: FakeNetworkAccess(),
          soundOutput: sound ?? RecordingSoundOutput(),
          hapticOutput: RecordingHapticOutput(),
          musicOutput: FakeMusicOutput(),
        ),
      ),
    );
    if (!settle) return;
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pumpAndSettle();
  }

  /// Даёт настоящим чтениям (пакет карт, настройки, колоды) закончиться и дорисовывает кадры.
  Future<void> settleReal(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pumpAndSettle();
  }

  /// Открывает выбор против бота и проходит шаг сложности: дальше экран выбора фракции.
  Future<void> openVsBotSetup(WidgetTester tester) async {
    await tester.tap(find.text(l10n.menuVsBot));
    await settleReal(tester);
    expect(find.text(l10n.difficultySelectTitle), findsOneWidget);
    await tester.tap(find.text(l10n.difficultySelectConfirm));
    await settleReal(tester);
  }

  /// Настройки: у экрана своя шапка, «назад» — круглая кнопка с подписью для диктора.
  Future<void> openSettingsAndReturn(WidgetTester tester) async {
    await tester.tap(find.text(l10n.menuSettings));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(l10n.settingsBack));
    await tester.pumpAndSettle();
    expect(find.byType(GwentLogo), findsOneWidget);
  }

  testWidgets('приложение открывается на главном меню на русском', (tester) async {
    await pumpApp(tester);

    expect(find.byType(GwentLogo), findsOneWidget);
    expect(tester.widget<GwentLogo>(find.byType(GwentLogo)).text, 'ГВИНТ');
    expect(find.text(l10n.menuHotSeat), findsOneWidget);
    expect(find.text(l10n.menuVsBot), findsOneWidget);
    expect(find.text(l10n.menuNetworkGame), findsOneWidget);
    expect(find.text(l10n.menuDecks), findsOneWidget);
    expect(find.text(l10n.menuSettings), findsOneWidget);
  });

  testWidgets('нажатие кнопки меню и стрелки «назад» звучит как выбор карты', (tester) async {
    final sound = RecordingSoundOutput();
    await pumpApp(tester, sound: sound);
    final before = sound.effects.where((effect) => effect == SoundEffect.select).length;

    await tester.tap(find.text(l10n.menuSettings));
    await tester.pumpAndSettle();
    expect(sound.effects.where((effect) => effect == SoundEffect.select).length, before + 1);

    await tester.tap(find.bySemanticsLabel(l10n.settingsBack));
    await tester.pumpAndSettle();
    expect(sound.effects.where((effect) => effect == SoundEffect.select).length, before + 2);
  });

  testWidgets('меню называет версию приложения и версию набора карт', (tester) async {
    await pumpApp(tester);

    expect(find.textContaining('Версия 1.2.3 · Набор карт'), findsOneWidget);
  });

  testWidgets('стартовые колоды подарены, играть можно сразу: подсказки про колоду нет', (tester) async {
    await pumpApp(tester);

    expect(find.text(l10n.menuNoDeckHint), findsNothing);
    expect(find.text(l10n.menuContentFailed), findsNothing);
    expect(await tester.runAsync(() => decks.watchAll().first), isNotEmpty);
  });

  testWidgets('набор карт не загрузился: играть нельзя, меню зовёт в конструктор и остаётся рабочим', (tester) async {
    await pumpApp(tester, source: InMemoryContentSource(const {}));

    expect(find.text(l10n.menuContentFailed), findsOneWidget);
    await tester.tap(find.text(l10n.menuHotSeat), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(l10n.setupBack), findsNothing);

    await openSettingsAndReturn(tester);
  });

  testWidgets('из меню открываются партии, лобби, колоды и настройки, «назад» возвращает в меню', (tester) async {
    await pumpApp(tester);

    // У экрана партии нет шапки: выход в меню — кнопка на нём.
    await tester.tap(find.text(l10n.menuHotSeat));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    await tester.pumpAndSettle();
    expect(find.byType(GwentLogo), findsOneWidget);

    await openVsBotSetup(tester);
    expect(find.text(l10n.factionSelectConfirm), findsOneWidget);
    // С выбора фракции «назад» ведёт к сложности, оттуда — в меню.
    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    await tester.pumpAndSettle();
    expect(find.text(l10n.difficultySelectTitle), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    await tester.pumpAndSettle();

    // Игра на двух телефонах: выбор способа, у экрана своя шапка с «назад» в меню.
    await tester.tap(find.text(l10n.menuNetworkGame));
    await tester.pumpAndSettle();
    expect(find.text(l10n.netPlayTitle), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    await tester.pumpAndSettle();
    expect(find.byType(GwentLogo), findsOneWidget);
    await openSettingsAndReturn(tester);
  });

  testWidgets('настройка «Подтверждать пас» доходит до экрана партии', (tester) async {
    await pumpApp(tester, settings: InMemorySettingsRepository()..saved = const AppSettings(confirmPass: true));
    await tester.tap(find.text(l10n.menuVsBot));
    await settleReal(tester);
    expect(tester.widget<MatchScreen>(find.byType(MatchScreen)).confirmPass, isTrue);
  });

  testWidgets('по умолчанию на экране партии пас держат, а не подтверждают', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(l10n.menuVsBot));
    await settleReal(tester);
    expect(tester.widget<MatchScreen>(find.byType(MatchScreen)).confirmPass, isFalse);
  });

  testWidgets('настройки, открытые поверх экрана партии: «назад» возвращает на этот экран, а не в меню', (
    tester,
  ) async {
    await pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(GwentLogo)));

    await openVsBotSetup(tester);
    expect(find.text(l10n.factionSelectConfirm), findsOneWidget);

    unawaited(router.push(AppRoutes.settings));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(l10n.settingsBack));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text(l10n.factionSelectConfirm), findsOneWidget);
  });

  testWidgets('настройки из меню: «Как играть» открывает список и тему, «назад» идёт по шагам обратно', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(l10n.menuSettings));
    await settleReal(tester);

    await tester.ensureVisible(find.text(l10n.settingsHowToPlay));
    await tester.tap(find.text(l10n.settingsHowToPlay));
    await settleReal(tester);
    expect(find.byType(HowToPlayScreen), findsOneWidget);
    expect(find.text(l10n.howToStartTutorial), findsOneWidget, reason: 'вне партии «Первую партию» можно начать');

    await tester.tap(find.text(l10n.howToRowsAndPowerTitle));
    await settleReal(tester);
    expect(find.byType(HowToTopicScreen), findsOneWidget);
    expect(find.text(l10n.howToRowsAndPowerText1), findsOneWidget);

    await tester.scrollUntilVisible(find.textContaining(l10n.howToNextTopic), 300);
    await tester.tap(find.textContaining(l10n.howToNextTopic));
    await settleReal(tester);
    expect(find.text(l10n.howToWeatherText1), findsOneWidget, reason: 'следующая тема заменяет страницу');

    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    await tester.pumpAndSettle();
    expect(find.byType(HowToPlayScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('настройки из меню: «Пройти обучение заново» запускает «Первую партию»', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(l10n.menuSettings));
    await settleReal(tester);

    await tester.ensureVisible(find.text(l10n.settingsReplayTutorial));
    await tester.tap(find.text(l10n.settingsReplayTutorial));
    await settleReal(tester);
    expect(find.byType(FirstMatchScreen), findsOneWidget);
  });

  testWidgets('справочник поверх партии: без «Первой партии», «назад» возвращает на экран партии', (tester) async {
    await pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(GwentLogo)));
    await openVsBotSetup(tester);

    unawaited(router.push(AppRoutes.howToPlay(overGame: true)));
    await settleReal(tester);
    expect(find.byType(HowToPlayScreen), findsOneWidget);
    expect(find.text(l10n.howToStartTutorial), findsNothing);

    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    await tester.pumpAndSettle();
    expect(find.byType(HowToPlayScreen), findsNothing);
    expect(find.text(l10n.factionSelectConfirm), findsOneWidget);
  });

  testWidgets('пауза в «Первой партии»: «Как играть» открывается поверх партии без кнопки обучения, «назад» в паузу', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text(l10n.menuSettings));
    await settleReal(tester);
    await tester.ensureVisible(find.text(l10n.settingsReplayTutorial));
    await tester.tap(find.text(l10n.settingsReplayTutorial));
    await settleReal(tester);
    expect(find.byType(FirstMatchScreen), findsOneWidget);

    for (var i = 0; i < 400 && find.text(l10n.tutorialStepCounter(1, 15)).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(MatchIntroView).evaluate().isNotEmpty) await tester.tap(find.byType(MatchIntroView));
      if (find.byType(MatchTossView).evaluate().isNotEmpty) await tester.tap(find.byType(MatchTossView));
    }
    await tester.tap(find.text(l10n.tutorialNext));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.bySemanticsLabel(l10n.pauseButtonSemantics));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(l10n.pauseHowToPlay));
    await settleReal(tester);
    expect(find.byType(HowToPlayScreen), findsOneWidget);
    expect(find.text(l10n.howToStartTutorial), findsNothing);

    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    await tester.pumpAndSettle();
    expect(find.byType(HowToPlayScreen), findsNothing);
    expect(find.text(l10n.pauseTitle), findsOneWidget, reason: 'пауза осталась открытой');
  });

  testWidgets('пауза в партии с ботом: «Как играть» открывается поверх партии без кнопки обучения', (tester) async {
    await pumpApp(tester);
    await openVsBotSetup(tester);
    await tester.tap(find.text(l10n.factionSelectConfirm));
    await settleReal(tester);
    await tester.tap(find.text(l10n.deckSelectPlay));
    for (var i = 0; i < 400 && find.bySemanticsLabel(l10n.pauseButtonSemantics).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(MatchIntroView).evaluate().isNotEmpty) await tester.tap(find.byType(MatchIntroView));
      if (find.byType(MatchTossView).evaluate().isNotEmpty) await tester.tap(find.byType(MatchTossView));
      if (find.text(l10n.matchRedrawDone).evaluate().isNotEmpty) await tester.tap(find.text(l10n.matchRedrawDone));
    }
    await tester.tap(find.bySemanticsLabel(l10n.pauseButtonSemantics));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(l10n.pauseHowToPlay));
    await settleReal(tester);
    expect(find.byType(HowToPlayScreen), findsOneWidget);
    expect(find.text(l10n.howToStartTutorial), findsNothing);

    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    await tester.pumpAndSettle();
    expect(find.text(l10n.pauseTitle), findsOneWidget);
  });

  testWidgets('настройки поверх партии: «Как играть» есть, «Пройти обучение заново» нет', (tester) async {
    await pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(GwentLogo)));
    await openVsBotSetup(tester);

    unawaited(router.push(AppRoutes.settingsOverGame));
    await settleReal(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.ensureVisible(find.text(l10n.settingsHowToPlay));
    expect(find.text(l10n.settingsHowToPlay), findsOneWidget);
    expect(find.text(l10n.settingsReplayTutorial), findsNothing);
  });

  testWidgets('неизвестная тема справочника ведёт к списку тем', (tester) async {
    await pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(GwentLogo)));

    router.go(AppRoutes.howToTopic('нет-такой'));
    await settleReal(tester);
    expect(find.byType(HowToPlayScreen), findsOneWidget);
  });

  testWidgets('комната и сетевая партия без активной игры уводят: комната на выбор способа, партия в меню', (
    tester,
  ) async {
    await pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(GwentLogo)));

    router.go(AppRoutes.playRoom);
    await tester.pumpAndSettle();
    expect(find.text(l10n.netPlayTitle), findsOneWidget);

    router.go(AppRoutes.playMatch);
    await tester.pumpAndSettle();
    expect(find.byType(GwentLogo), findsOneWidget);
  });

  testWidgets('игра через интернет: способ запоминается при возврате, «Создать комнату» ведёт в комнату с кодом', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text(l10n.menuNetworkGame));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.netMethodInternet));
    await tester.pump();
    await tester.tap(find.text(l10n.netEnterCode));
    await tester.pumpAndSettle();
    expect(find.text(l10n.netOnlineCodeLabel), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    await tester.pumpAndSettle();
    expect(find.text(l10n.netCreateRoom), findsOneWidget, reason: 'выбран «Через интернет»');

    await tester.tap(find.text(l10n.netCreateRoom));
    await settleReal(tester);
    expect(find.text(l10n.netOnlineCodeCaption), findsOneWidget);
    expect(find.text(l10n.netOnlineCodeCopy), findsOneWidget);

    // Уход из комнаты закрывает игру, а с ней и таймеры связи хоста.
    await tester.tap(find.text(l10n.dialogCancel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.netLeaveConfirm));
    await settleReal(tester);
    expect(find.text(l10n.netCreateRoom), findsOneWidget, reason: 'после выхода выбран «Через интернет»');
  });

  testWidgets('колоды: список, новая колода в конструкторе, возврат по шагам в меню', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(l10n.menuDecks));
    await tester.pumpAndSettle();
    expect(find.text(l10n.deckListTitle), findsOneWidget);
    expect(find.text(l10n.deckListNew), findsOneWidget, reason: 'есть кнопка «Новая колода»');

    await tester.tap(find.text(l10n.deckListNew));
    await tester.pumpAndSettle();
    expect(find.text(l10n.editorEyebrow.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.editorHintPickLeader), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(l10n.editorBack).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.deckListTitle), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    await tester.pumpAndSettle();
    expect(find.byType(GwentLogo), findsOneWidget);
  });

  testWidgets('колоды: открытая колода показывает своё название, сохранение возвращает в список', (tester) async {
    await pumpApp(tester);
    final saved = (await tester.runAsync(() => decks.watchAll().first))!.first;

    await tester.tap(find.text(l10n.menuDecks));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^${RegExp.escape(l10n.deckListOpen(saved.name))}')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, saved.name);

    await tester.tap(find.text(l10n.editorSave));
    await tester.pumpAndSettle();
    expect(find.text(l10n.deckListTitle), findsOneWidget);
  });

  testWidgets('«Изменить» на шаге колоды открывает конструктор этой колоды; «назад» возвращает на тот же шаг', (
    tester,
  ) async {
    await pumpApp(tester);

    await openVsBotSetup(tester);
    await tester.tap(find.text(l10n.factionSelectConfirm));
    await tester.pumpAndSettle();
    expect(find.text(l10n.deckSelectTitle), findsOneWidget);

    await tester.tap(find.text(l10n.deckSelectEdit));
    await tester.pumpAndSettle();
    expect(find.text(l10n.editorEyebrow.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.deckSelectTitle), findsNothing);

    await tester.tap(find.bySemanticsLabel(l10n.editorBack).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.deckSelectTitle), findsOneWidget);
  });

  testWidgets('режим из меню попадает на выбор сложности или фракции: вдвоём шаг называет игрока', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(l10n.menuHotSeat));
    await tester.pumpAndSettle();
    expect(find.text(l10n.setupStepSeat(l10n.playerNumbered(1), 1, 2).toUpperCase()), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(l10n.setupBack));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.menuVsBot));
    await settleReal(tester);
    expect(find.text(l10n.setupStep(1, 3).toUpperCase()), findsOneWidget);
    expect(find.text(l10n.difficultySelectTitle), findsOneWidget);
  });

  testWidgets('заставка идёт один раз при запуске и закрывает меню, пока данные не готовы', (tester) async {
    await pumpApp(tester, reduceMotion: false, settle: false);
    await tester.pump();

    expect(find.text(l10n.menuSplashLoading), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pump(const Duration(seconds: 2));

    expect(find.text(l10n.menuSplashLoading), findsNothing);
    expect(find.text(l10n.menuHotSeat), findsOneWidget);

    // Возврат в меню заставку не повторяет.
    await tester.tap(find.text(l10n.menuDecks));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byType(ChevronButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(l10n.menuHotSeat), findsOneWidget);
    expect(find.text(l10n.menuSplashLoading), findsNothing);
  });

  testWidgets('список колод пуст, когда колод нет', (tester) async {
    await pumpApp(tester, source: InMemoryContentSource(const {}));

    await tester.tap(find.text(l10n.menuDecks));
    await tester.pumpAndSettle();

    expect(find.text(l10n.deckListEmpty), findsOneWidget);
  });

  testWidgets('список колод показывает сохранённые колоды и число карт, пока набор карт не загрузился', (tester) async {
    await decks.save(testDeck(name: 'Ан Крайт', cards: const {'a': 20, 'b': 2}));
    await pumpApp(tester, source: InMemoryContentSource(const {}));

    await tester.tap(find.text(l10n.menuDecks));
    await tester.pumpAndSettle();

    expect(find.text('Ан Крайт'), findsOneWidget);
    expect(find.text('22 карты'), findsOneWidget);
  });
}
