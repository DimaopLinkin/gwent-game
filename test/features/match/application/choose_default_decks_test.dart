import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/application/get_active_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/match/application/choose_default_decks.dart';
import 'package:gwent_content/gwent_content.dart' as content;

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/fakes.dart';

void main() {
  late InMemoryDeckRepository repository;

  setUp(() => repository = InMemoryDeckRepository());

  ChooseDefaultDecks scenario(DeckRules rules) {
    final source = FakeDeckRulesSource(rules);
    final starter = CreateStarterDeck(repository, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator());
    return ChooseDefaultDecks(source, GetActiveDeck(repository, source, starter, DeckSelectionLock()));
  }

  test('места получают колоды двух первых фракций пакета: играют разные фракции', () async {
    final decks = (await scenario(smallDeckRules)())!;

    final one = (await repository.findById(decks.deckOne))!;
    final two = (await repository.findById(decks.deckTwo))!;
    expect(one.factionId, Small.skellige);
    expect(two.factionId, Small.monsters);
    expect(smallDeckRules.check(one), isEmpty);
    expect(smallDeckRules.check(two), isEmpty);
  });

  test('если у фракции есть активная колода игрока, берётся она, а не новая стартовая', () async {
    await repository.save(smallSkelligeDeck(id: 'mine'), activate: true);

    final decks = (await scenario(smallDeckRules)())!;

    expect(decks.deckOne, 'mine');
    expect(await repository.findByFaction(Small.skellige), hasLength(1));
  });

  test('повторный вызов отдаёт те же колоды и не плодит новые', () async {
    final choose = scenario(smallDeckRules);
    final first = (await choose())!;
    final second = (await choose())!;

    expect((second.deckOne, second.deckTwo), (first.deckOne, first.deckTwo));
    expect(await repository.watchAll().first, hasLength(2));
  });

  test('в пакете нет фракций с колодой: колод по умолчанию нет', () async {
    final rules = smallPack.rules;
    final withoutDecks = content.ContentPack(
      manifest: smallPack.manifest,
      rules: content.PackRules(
        gameRules: rules.gameRules,
        zones: const [],
        fractions: [rules.fractions.first],
        fractionAbilities: const [],
        squadAbilities: const [],
        specialAbilities: const [],
        leaderAbilities: const [],
        squadCards: const [],
        specialCards: const [],
        leaderCards: const [],
      ),
      strings: smallPack.strings,
    );

    expect(await scenario(deckRulesFor(withoutDecks))(), isNull);
  });
}
