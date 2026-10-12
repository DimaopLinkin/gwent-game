import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/app/app_dependencies.dart';
import 'package:gwent/src/app/gwent_app.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent_content/gwent_content.dart';

import '../support/factories.dart';
import '../support/fakes.dart';

void main() {
  late InMemoryDeckRepository decks;
  late AppLocalizations l10n;

  setUp(() async {
    decks = InMemoryDeckRepository();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      GwentApp(
        dependencies: AppDependencies(
          contentSource: InMemoryContentSource(const {}),
          deckRepository: decks,
          settingsRepository: InMemorySettingsRepository(),
          matchHistoryRepository: InMemoryMatchHistoryRepository(),
          clock: FakeClock(DateTime.utc(2026, 10, 11)),
          idGenerator: SequentialIdGenerator(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAndReturn(WidgetTester tester, String button, String title) async {
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, title), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(l10n.appTitle), findsOneWidget);
  }

  testWidgets('приложение открывается на главном меню на русском', (tester) async {
    await pumpApp(tester);

    expect(find.text('Гвинт'), findsOneWidget);
    expect(find.text(l10n.menuHotSeat), findsOneWidget);
    expect(find.text(l10n.menuNetworkGame), findsOneWidget);
    expect(find.text(l10n.menuDecks), findsOneWidget);
  });

  testWidgets('из меню открываются поле, лобби и колоды, «назад» возвращает в меню', (tester) async {
    await pumpApp(tester);

    await openAndReturn(tester, l10n.menuHotSeat, l10n.matchTitle);
    await openAndReturn(tester, l10n.menuNetworkGame, l10n.lobbyTitle);
    await openAndReturn(tester, l10n.menuDecks, l10n.deckBuilderTitle);
  });

  testWidgets('конструктор колоды показывает пустой список', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(l10n.menuDecks));
    await tester.pumpAndSettle();

    expect(find.text(l10n.deckListEmpty), findsOneWidget);
  });

  testWidgets('конструктор колоды показывает сохранённые колоды и число карт', (tester) async {
    await decks.save(testDeck(name: 'Ан Крайт', cards: const {'a': 20, 'b': 2}));
    await pumpApp(tester);

    await tester.tap(find.text(l10n.menuDecks));
    await tester.pumpAndSettle();

    expect(find.text('Ан Крайт'), findsOneWidget);
    expect(find.text('22 карты'), findsOneWidget);
  });
}
