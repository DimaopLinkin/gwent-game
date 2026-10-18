import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/application/get_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/application/save_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_screen.dart';
import 'package:gwent_engine/gwent_engine.dart' show Faction;

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/match_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late DeckRules rules;
  late AppLocalizations l10n;

  setUpAll(() async {
    await loadDesignFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    content = await loadBaseContent();
    rules = await GameContentDeckRulesSource(LoadGameContent(AssetContentSource.basePack(rootBundle))).load();
  });

  late InMemoryDeckRepository repository;
  var exits = 0;

  setUp(() {
    repository = InMemoryDeckRepository();
    exits = 0;
  });

  Deck skelligeDeck() => realDeck(content, Faction.skellige, id: 'deck-1').copyWith(name: 'Драккары');

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? deckId,
    Size size = const Size(390, 844),
    Widget? banner,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = DeckEditorCubit(
      loadDeckRules: LoadDeckRules(FakeDeckRulesSource(rules)),
      getDeck: GetDeck(repository),
      saveDeck: SaveDeck(repository, FakeClock(DateTime.utc(2026, 10, 18)), SequentialIdGenerator()),
      newDeckName: l10n.deckListNew,
      deckId: deckId,
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      localizedApp(
        BlocProvider.value(
          value: cubit,
          child: DeckEditorScreen(onExit: () => exits++, banner: banner),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  int minUnits() => rules.gameRules.minUnitCards;
  int maxSpecials() => rules.gameRules.maxSpecialCards;

  group('готовая колода', () {
    testWidgets('показывает название, фракцию, счётчики по правилам и подсказку «соответствует»', (tester) async {
      await repository.save(skelligeDeck());
      await pumpEditor(tester, deckId: 'deck-1');

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Драккары');
      expect(find.text(rules.factionInfos.firstWhere((f) => f.key == 'skellige').name), findsOneWidget);
      expect(find.textContaining('/${minUnits()}'), findsOneWidget);
      expect(find.textContaining('/${maxSpecials()}'), findsOneWidget);
      expect(find.text(l10n.editorHintValid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('«Сохранить» сохраняет колоду и закрывает конструктор', (tester) async {
      await repository.save(skelligeDeck());
      await pumpEditor(tester, deckId: 'deck-1');

      await tester.enterText(find.byType(TextField), 'Новое имя');
      await tester.tap(find.text(l10n.editorSave));
      await tester.pump();
      await tester.pump();

      expect(exits, 1);
      expect((await repository.findById('deck-1'))!.name, 'Новое имя');
    });

    testWidgets('кнопка «назад» выходит без сохранения', (tester) async {
      final handle = tester.ensureSemantics();
      await repository.save(skelligeDeck());
      await pumpEditor(tester, deckId: 'deck-1');

      await tester.enterText(find.byType(TextField), 'Не сохранять');
      await tester.tap(find.bySemanticsLabel(l10n.editorBack).first);

      expect(exits, 1);
      expect((await repository.findById('deck-1'))!.name, 'Драккары');
      handle.dispose();
    });

    testWidgets('смена фракции просит подтверждение; отмена оставляет фракцию, подтверждение меняет', (tester) async {
      final handle = tester.ensureSemantics();
      await repository.save(skelligeDeck());
      await pumpEditor(tester, deckId: 'deck-1');
      final skellige = rules.factionInfos.firstWhere((f) => f.key == 'skellige');
      final next = rules.factionInfos[(rules.factionInfos.indexOf(skellige) + 1) % rules.factionInfos.length];

      await tester.tap(find.bySemanticsLabel(l10n.factionSelectNext));
      await tester.pumpAndSettle();
      expect(find.text(l10n.editorFactionKept), findsOneWidget);

      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();
      expect(find.text(l10n.editorFactionKept), findsNothing);
      expect(find.text(skellige.name), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(l10n.factionSelectNext));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.editorFactionChange));
      await tester.pumpAndSettle();

      expect(find.text(next.name), findsOneWidget);
      expect(find.text(l10n.editorHintPickLeader), findsOneWidget);
      handle.dispose();
    });

    testWidgets('долгое нажатие открывает просмотр карты с кнопкой «Убрать из колоды»', (tester) async {
      await repository.save(skelligeDeck());
      await pumpEditor(tester, deckId: 'deck-1');
      final before = tester.widgetList(find.byType(GwentCard)).length;

      await tester.longPress(find.byType(GwentCard).at(1));
      await tester.pumpAndSettle();
      expect(find.text(l10n.editorPreviewRemove), findsOneWidget);
      expect(find.textContaining(' · в колоде '), findsOneWidget);

      await tester.tap(find.text(l10n.editorPreviewRemove));
      await tester.pumpAndSettle();
      expect(find.text(l10n.editorPreviewRemove), findsNothing);
      expect(tester.widgetList(find.byType(GwentCard)).length, lessThanOrEqualTo(before));
    });
  });

  group('новая колода', () {
    testWidgets('без лидера: подсказка красная, сохранить нельзя', (tester) async {
      await pumpEditor(tester);

      expect(find.text(l10n.editorHintPickLeader), findsOneWidget);
      final save = tester.widget<GestureDetector>(
        find.ancestor(of: find.text(l10n.editorSave), matching: find.byType(GestureDetector)).first,
      );
      expect(save.onTap, isNull);
      final draft = tester.widget<GestureDetector>(
        find.ancestor(of: find.text(l10n.editorSaveDraft), matching: find.byType(GestureDetector)).first,
      );
      expect(draft.onTap, isNull);
    });

    testWidgets('лидер из листа убирает первое замечание; тап по карте кладёт её в колоду', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpEditor(tester);

      await tester.tap(find.bySemanticsLabel(l10n.editorPickLeader));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.leaderSelectConfirm));
      await tester.pumpAndSettle();
      expect(find.text(l10n.editorHintNeedUnits(minUnits())), findsOneWidget);

      await tester.tap(find.byType(GwentCard).at(1));
      await tester.pumpAndSettle();
      expect(find.text(l10n.editorHintNeedUnits(minUnits() - 1)), findsOneWidget);
      expect(
        find.text(l10n.editorCopiesOf(1, 1)).evaluate().length + find.textContaining(' из ').evaluate().length,
        greaterThan(0),
      );

      await tester.tap(find.text(l10n.editorSaveDraft));
      await tester.pump();
      await tester.pump();
      expect(exits, 1);
      expect((await repository.findById('id-1'))!.cards.values.fold(0, (a, b) => a + b), 1);
      handle.dispose();
    });

    testWidgets('вкладка «Колода» пуста, фильтр без карт показывает пояснение', (tester) async {
      await pumpEditor(tester);

      await tester.tap(find.textContaining(l10n.editorTabDeck, findRichText: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.editorFilterHero).last);
      await tester.pumpAndSettle();

      expect(find.text(l10n.editorEmptyDeckTitle), findsOneWidget);
      expect(find.text(l10n.editorEmptyDeckText(l10n.editorFilterHero)), findsOneWidget);
    });

    testWidgets('«Только доступные» есть на вкладке «Коллекция» и пропадает на вкладке «Колода»', (tester) async {
      await pumpEditor(tester);
      expect(find.text(l10n.editorOnlyAvailable), findsOneWidget);

      await tester.tap(find.textContaining(l10n.editorTabDeck, findRichText: true));
      await tester.pumpAndSettle();

      expect(find.text(l10n.editorOnlyAvailable), findsNothing);
    });

    testWidgets('плашка сверху: встроенный сценарий может поставить свою', (tester) async {
      await pumpEditor(tester, banner: const Text('плашка лобби'));

      expect(find.text('плашка лобби'), findsOneWidget);
    });
  });

  group('экран', () {
    testWidgets('колоды нет — сообщение; назад работает', (tester) async {
      await pumpEditor(tester, deckId: 'нет-такой');

      expect(find.text(l10n.editorNotFound), findsOneWidget);
    });

    for (final size in [const Size(320, 568), const Size(375, 667), const Size(430, 932)]) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()}: ничего не переполняется', (tester) async {
        await repository.save(skelligeDeck());
        await pumpEditor(tester, deckId: 'deck-1', size: size);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text(l10n.editorFilterAll));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('на маленьком экране кнопки сохранения остаются видны, а карты прокручиваются', (tester) async {
      await repository.save(skelligeDeck());
      await pumpEditor(tester, deckId: 'deck-1', size: const Size(320, 568));

      expect(find.text(l10n.editorSave), findsOneWidget);
      final save = tester.getRect(find.text(l10n.editorSave));
      expect(save.bottom, lessThanOrEqualTo(568));
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
