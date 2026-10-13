import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/app/app_dependencies.dart';
import 'package:gwent/src/app/gwent_app.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/menu/presentation/menu_backdrop.dart';
import 'package:gwent_content/gwent_content.dart';

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
          settingsRepository: InMemorySettingsRepository(),
          matchHistoryRepository: InMemoryMatchHistoryRepository(),
          clock: FakeClock(DateTime.utc(2026, 10, 11)),
          idGenerator: SequentialIdGenerator(),
          seedGenerator: FixedSeedGenerator(1),
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

  Future<void> openAndReturn(WidgetTester tester, String button, String title) async {
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, title), findsOneWidget);

    await tester.tap(find.byType(BackButton));
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
    expect(find.text(l10n.matchExit), findsNothing);

    await openAndReturn(tester, l10n.menuSettings, l10n.settingsTitle);
  });

  testWidgets('из меню открываются партии, лобби, колоды и настройки, «назад» возвращает в меню', (tester) async {
    await pumpApp(tester);

    // У экрана партии нет шапки: выход в меню — кнопка на нём.
    await tester.tap(find.text(l10n.menuHotSeat));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.matchExit));
    await tester.pumpAndSettle();
    expect(find.byType(GwentLogo), findsOneWidget);

    await tester.tap(find.text(l10n.menuVsBot));
    await tester.pumpAndSettle();
    expect(find.text(l10n.matchSetupStart), findsOneWidget);
    await tester.tap(find.text(l10n.matchExit));
    await tester.pumpAndSettle();

    await openAndReturn(tester, l10n.menuNetworkGame, l10n.lobbyTitle);
    await openAndReturn(tester, l10n.menuDecks, l10n.deckBuilderTitle);
    await openAndReturn(tester, l10n.menuSettings, l10n.settingsTitle);
  });

  testWidgets('режим из меню попадает на экран выбора колод', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(l10n.menuHotSeat));
    await tester.pumpAndSettle();
    expect(find.text(l10n.matchSetupDeckTwo), findsOneWidget);
    await tester.tap(find.text(l10n.matchExit));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.menuVsBot));
    await tester.pumpAndSettle();
    expect(find.text(l10n.matchSetupDeckBot), findsOneWidget);
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
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(l10n.menuHotSeat), findsOneWidget);
    expect(find.text(l10n.menuSplashLoading), findsNothing);
  });

  testWidgets('конструктор колоды показывает пустой список, когда колод нет', (tester) async {
    await pumpApp(tester, source: InMemoryContentSource(const {}));

    await tester.tap(find.text(l10n.menuDecks));
    await tester.pumpAndSettle();

    expect(find.text(l10n.deckListEmpty), findsOneWidget);
  });

  testWidgets('конструктор колоды показывает сохранённые колоды и число карт', (tester) async {
    await decks.save(testDeck(name: 'Ан Крайт', cards: const {'a': 20, 'b': 2}));
    await pumpApp(tester, source: InMemoryContentSource(const {}));

    await tester.tap(find.text(l10n.menuDecks));
    await tester.pumpAndSettle();

    expect(find.text('Ан Крайт'), findsOneWidget);
    expect(find.text('22 карты'), findsOneWidget);
  });
}
