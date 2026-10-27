import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/application/ensure_starter_decks.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/menu/application/load_menu.dart';
import 'package:gwent/src/features/menu/presentation/menu_backdrop.dart';
import 'package:gwent/src/features/menu/presentation/menu_cubit.dart';
import 'package:gwent/src/features/menu/presentation/menu_screen.dart';
import 'package:gwent/src/features/menu/presentation/menu_state.dart';
import 'package:gwent/src/features/menu/presentation/splash_layer.dart';
import 'package:gwent/src/features/tutorial/application/watch_first_match_passed.dart';
import 'package:gwent_content/gwent_content.dart';

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/screen_guards.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryDeckRepository decks;
  late AppLocalizations l10n;
  late List<String> taps;

  setUpAll(loadDesignFonts);

  setUp(() async {
    decks = InMemoryDeckRepository();
    taps = [];
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  /// Меню над настоящими сценариями. Набор карт читается из ассетов настоящим временем, поэтому ждём его вне
  /// фальшивых часов. При «уменьшить движение» заставка исчезает сразу, а свеча не мерцает.
  Future<MenuCubit> pumpMenu(
    WidgetTester tester, {
    ContentSource? source,
    bool reduceMotion = true,
    bool waitForReady = true,
    Duration minSplash = Duration.zero,
    Size size = const Size(390, 844),
    InMemorySettingsRepository? settings,
  }) async {
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final content = LoadGameContent(source ?? AssetContentSource.basePack(rootBundle));
    final starter = CreateStarterDeck(decks, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator());
    final cubit = MenuCubit(
      LoadMenu(
        const FakeAppInfo('1.2.3'),
        content,
        EnsureStarterDecks(decks, GameContentDeckRulesSource(content), starter, DeckSelectionLock()),
      ),
      WatchDecks(decks),
      minSplash: minSplash,
      watchFirstMatchPassed: settings == null ? null : WatchFirstMatchPassed(settings),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: localizedScreen(
          MenuScreen(
            onHotSeat: () => taps.add('hotSeat'),
            onBot: () => taps.add('bot'),
            onNetworkGame: () => taps.add('network'),
            onDecks: () => taps.add('decks'),
            onHistory: () => taps.add('history'),
            onTutorial: () => taps.add('tutorial'),
            onSettings: () => taps.add('settings'),
          ),
        ),
      ),
    );
    if (waitForReady) {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(seconds: 2));
      }
    }
    expectNoFallbackTextStyle(tester);
    return cubit;
  }

  GwentButton button(WidgetTester tester, String label) =>
      tester.widget<GwentButton>(find.widgetWithText(GwentButton, label));

  testWidgets('есть набор и колода: шесть кнопок, игровые доступны, подсказки нет, версии названы', (tester) async {
    await pumpMenu(tester);

    for (final label in [
      l10n.menuHotSeat,
      l10n.menuVsBot,
      l10n.menuNetworkGame,
      l10n.menuDecks,
      l10n.menuHistoryShort,
      l10n.menuTutorial,
      l10n.menuSettings,
    ]) {
      expect(button(tester, label).onPressed, isNotNull, reason: label);
    }
    expect(find.text(l10n.menuNoDeckHint), findsNothing);
    expect(find.text(l10n.menuContentFailed), findsNothing);
    expect(find.textContaining('Версия 1.2.3 · Набор карт'), findsOneWidget);
    expect(tester.widget<GwentLogo>(find.byType(GwentLogo)).text, 'ГВИНТ');
  });

  testWidgets('каждая кнопка вызывает свой переход', (tester) async {
    await pumpMenu(tester);

    for (final label in [
      l10n.menuHotSeat,
      l10n.menuVsBot,
      l10n.menuNetworkGame,
      l10n.menuDecks,
      l10n.menuHistoryShort,
      l10n.menuTutorial,
      l10n.menuSettings,
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
    }
    expect(taps, ['hotSeat', 'bot', 'network', 'decks', 'history', 'tutorial', 'settings']);
  });

  testWidgets('зоны нажатия кнопок меню не меньше 44 pt', (tester) async {
    await pumpMenu(tester);
    for (final label in [
      l10n.menuHotSeat,
      l10n.menuVsBot,
      l10n.menuNetworkGame,
      l10n.menuDecks,
      l10n.menuHistoryShort,
      l10n.menuTutorial,
      l10n.menuSettings,
    ]) {
      expect(tester.getSize(find.widgetWithText(GwentButton, label)).height, greaterThanOrEqualTo(44), reason: label);
    }
  });

  testWidgets('колод нет: игровые кнопки погашены, «Колоды» и «Настройки» доступны, подсказка зовёт в конструктор', (
    tester,
  ) async {
    final cubit = await pumpMenu(tester);
    final saved = (await tester.runAsync(() => decks.watchAll().first))!;
    for (final deck in saved) {
      await tester.runAsync(() => decks.delete(deck.id));
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump();
    expect(cubit.state, isA<MenuReady>().having((state) => state.hasDeck, 'hasDeck', isFalse));

    expect(find.text(l10n.menuNoDeckHint), findsOneWidget);
    for (final label in [l10n.menuHotSeat, l10n.menuVsBot, l10n.menuNetworkGame]) {
      expect(button(tester, label).onPressed, isNull, reason: label);
    }
    expect(button(tester, l10n.menuDecks).onPressed, isNotNull);
    expect(button(tester, l10n.menuDecks).labelColor, isNotNull, reason: '«Колоды» подсвечены');
    expect(button(tester, l10n.menuSettings).onPressed, isNotNull);

    await tester.tap(find.text(l10n.menuToBuilder));
    expect(taps, ['decks']);
    await tester.tap(find.text(l10n.menuHotSeat), warnIfMissed: false);
    expect(taps, ['decks'], reason: 'погашенная кнопка не нажимается');
  });

  testWidgets('набор карт не загрузился: подсказка об этом, версия набора не называется', (tester) async {
    await pumpMenu(tester, source: InMemoryContentSource(const {}));

    expect(find.text(l10n.menuContentFailed), findsOneWidget);
    expect(find.text('Версия 1.2.3'), findsOneWidget);
    expect(button(tester, l10n.menuVsBot).onPressed, isNull);
    expect(button(tester, l10n.menuDecks).onPressed, isNotNull);
  });

  testWidgets('заставка закрывает меню, пока данные не готовы: кнопки под ней не нажимаются', (tester) async {
    await pumpMenu(tester, reduceMotion: false, waitForReady: false, minSplash: const Duration(minutes: 5));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SplashLayer), findsOneWidget);
    expect(find.text(l10n.menuSplashLoading), findsOneWidget);
    await tester.tapAt(const Offset(195, 700));
    expect(taps, isEmpty);
    expect(find.text(l10n.menuHotSeat), findsOneWidget, reason: 'меню уже нарисовано под заставкой');
    expect(button(tester, l10n.menuHotSeat).onPressed, isNull, reason: 'но игровые кнопки погашены');
    // Заставка не короче заданного времени: дожидаемся его, чтобы не оставить таймер.
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('когда данные готовы, полоса доходит до конца, заставка растворяется и пропадает', (tester) async {
    // Пустой источник отвечает отказом сразу: данные «готовы» без чтения ассетов, и время заставки считаем сами.
    final cubit = await pumpMenu(
      tester,
      source: InMemoryContentSource(const {}),
      reduceMotion: false,
      waitForReady: false,
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    // Нулевая заставка заканчивается таймером нулевой длины: часы нужно сдвинуть, хотя бы чуть-чуть.
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(cubit.state, isA<MenuReady>());
    expect(find.byType(SplashLayer), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.menuSplashReady), findsOneWidget, reason: 'полоса дошла до конца');
    expect(find.text(l10n.menuSplashLoading), findsNothing);
    // Заставка уже растворяется: нажатия идут к меню под ней.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SplashLayer), findsOneWidget);
    await tester.tap(find.text(l10n.menuDecks));
    expect(taps, ['decks']);
    await tester.pump(SplashLayer.finish);
    await tester.pump();
    expect(find.byType(SplashLayer), findsNothing);
    expect(button(tester, l10n.menuDecks).onPressed, isNotNull);
  });

  testWidgets('при «уменьшить движение» заставка исчезает сразу, как только данные готовы', (tester) async {
    await pumpMenu(tester);
    await tester.pump();
    expect(find.byType(SplashLayer), findsNothing);
  });

  testWidgets('на маленьком экране меню прокручивается без переполнения', (tester) async {
    await pumpMenu(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text(l10n.menuSettings), 100, scrollable: find.byType(Scrollable).first);
  });

  testWidgets('три малые кнопки ряда помещаются на узком экране без переполнения', (tester) async {
    await pumpMenu(tester, size: const Size(320, 568));
    await tester.scrollUntilVisible(find.text(l10n.menuTutorial), 100, scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    for (final label in [l10n.menuHistoryShort, l10n.menuTutorial, l10n.menuSettings]) {
      final rect = tester.getRect(find.widgetWithText(GwentButton, label));
      expect(rect.left, greaterThanOrEqualTo(0), reason: label);
      expect(rect.right, lessThanOrEqualTo(320), reason: label);
    }
  });

  testWidgets('пока «Первая партия» не пройдена, «Обучение» помечено «Новое», после прохождения метки нет', (
    tester,
  ) async {
    final settings = InMemorySettingsRepository();
    await pumpMenu(tester, settings: settings);
    expect(find.text(l10n.menuTutorialNew), findsOneWidget);

    await tester.runAsync(() => settings.save(settings.saved.copyWith(firstMatchPassed: true)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text(l10n.menuTutorialNew), findsNothing);
    expect(find.bySemanticsLabel(l10n.menuTutorialDone), findsOneWidget);
  });

  testWidgets('без слежения за флагом метки «Новое» нет', (tester) async {
    await pumpMenu(tester);
    expect(find.text(l10n.menuTutorialNew), findsNothing);
  });
}
