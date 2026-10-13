import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/application/get_active_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/match/application/choose_opponent_deck.dart';
import 'package:gwent_content/gwent_content.dart' as content;

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/fakes.dart';

void main() {
  late InMemoryDeckRepository repository;
  late FakeDeckRulesSource rules;
  late ChooseOpponentDeck choose;

  setUp(() {
    repository = InMemoryDeckRepository();
    rules = FakeDeckRulesSource();
    final getActive = GetActiveDeck(
      repository,
      rules,
      CreateStarterDeck(repository, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator()),
      DeckSelectionLock(),
    );
    choose = ChooseOpponentDeck(rules, getActive);
  });

  test('бот играет следующей по порядку пакета фракцией, колодой, которую игрок выбрал для неё', () async {
    final chosen = smallSkelligeDeck(id: 'skellige-chosen');
    await repository.save(chosen);
    await repository.save(smallSkelligeDeck(id: 'skellige-other'), activate: true);
    // Skellige стоит первой, Monsters второй: против Скеллиге бот играет Чудовищами.
    expect((await choose(Small.skellige)).factionId, Small.monsters);

    // Против последней фракции бот играет первой, её активной колодой.
    await repository.setActive(chosen.id);
    expect(await choose(Small.monsters), chosen);
  });

  test('у следующей фракции нет колод: создаётся стартовая колода', () async {
    final deck = await choose(Small.skellige);

    expect(deck.factionId, Small.monsters);
    expect(rules.rules.check(deck), isEmpty);
    expect(await repository.findActiveDeckId(Small.monsters), deck.id);
  });

  test('неизвестная фракция игрока: бот играет первой фракцией пакета', () async {
    expect((await choose('нет такой')).factionId, Small.skellige);
  });

  test('в пакете нет фракций с колодой', () async {
    final pack = content.ContentPack(
      manifest: smallPack.manifest,
      rules: content.PackRules(
        gameRules: smallPack.rules.gameRules,
        zones: const [],
        fractions: const [],
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
    rules.rules = deckRulesFor(pack);

    await expectLater(choose(Small.skellige), throwsA(isA<NotADeckFactionException>()));
  });
}
