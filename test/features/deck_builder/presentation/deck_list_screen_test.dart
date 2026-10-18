import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/application/delete_deck.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_screen.dart';
import 'package:gwent_engine/gwent_engine.dart' show Faction;

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/match_fixtures.dart';

final class _BrokenRulesSource implements DeckRulesSource {
  @override
  Future<DeckRules> load() async => throw StateError('набор карт не загрузился');
}

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
  final opened = <String>[];
  var created = 0;
  var backs = 0;

  setUp(() {
    repository = InMemoryDeckRepository();
    opened.clear();
    created = 0;
    backs = 0;
  });

  Deck valid(String id, String name) => realDeck(content, Faction.skellige, id: id).copyWith(name: name);

  Deck tooSmall(String id, String name) {
    final full = valid(id, name);
    return full.copyWith(cards: {full.cards.keys.first: 1});
  }

  Future<void> pumpList(WidgetTester tester, {DeckRulesSource? source, Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = DeckListCubit(
      WatchDecks(repository),
      LoadDeckRules(source ?? FakeDeckRulesSource(rules)),
      DeleteDeck(repository),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      localizedApp(
        BlocProvider.value(
          value: cubit,
          child: DeckListScreen(onOpen: opened.add, onNew: () => created++, onBack: () => backs++),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('колоды со счётчиками по правилам; нарушающая правила помечена', (tester) async {
    await repository.save(valid('a', 'Драккары'));
    await repository.save(tooSmall('b', 'Заготовка'));
    await pumpList(tester);

    expect(find.text('Драккары'), findsOneWidget);
    expect(find.text('Заготовка'), findsOneWidget);
    expect(find.text(l10n.deckListInvalid), findsOneWidget, reason: 'отметка только у колоды, нарушающей правила');
    expect(find.text(l10n.deckListUnits(1, rules.gameRules.minUnitCards)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('тап по колоде открывает её, «Новая колода» и «назад» зовут свои колбэки', (tester) async {
    final handle = tester.ensureSemantics();
    await repository.save(valid('a', 'Драккары'));
    await pumpList(tester);

    await tester.tap(find.bySemanticsLabel(l10n.deckListOpen('Драккары')));
    await tester.tap(find.text(l10n.deckListNew));
    await tester.tap(find.bySemanticsLabel(l10n.setupBack));

    expect(opened, ['a']);
    expect(created, 1);
    expect(backs, 1);
    handle.dispose();
  });

  testWidgets('удаление спрашивает подтверждение: отмена оставляет колоду, «Удалить» убирает', (tester) async {
    final handle = tester.ensureSemantics();
    await repository.save(valid('a', 'Драккары'));
    await pumpList(tester);

    await tester.tap(find.bySemanticsLabel(l10n.deckListDelete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.deckDeleteTitle), findsOneWidget);
    await tester.tapAt(const Offset(195, 60));
    await tester.pumpAndSettle();
    expect(find.text('Драккары'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(l10n.deckListDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.deckDeleteConfirm));
    await tester.pumpAndSettle();

    expect(find.text('Драккары'), findsNothing);
    expect(find.text(l10n.deckListEmpty), findsOneWidget);
    handle.dispose();
  });

  testWidgets('без набора карт колоды видны с числом карт и без отметок', (tester) async {
    await repository.save(valid('a', 'Драккары'));
    await pumpList(tester, source: _BrokenRulesSource());

    expect(find.text('Драккары'), findsOneWidget);
    expect(find.text(l10n.deckCardCount(valid('a', '').cardCount)), findsOneWidget);
    expect(find.text(l10n.deckListInvalid), findsNothing);
  });

  testWidgets('пустой список: сообщение и «Новая колода»; на маленьком экране без переполнения', (tester) async {
    await pumpList(tester, size: const Size(320, 568));

    expect(find.text(l10n.deckListEmpty), findsOneWidget);
    expect(find.text(l10n.deckListNew), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
