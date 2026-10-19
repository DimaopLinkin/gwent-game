import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/match/application/choose_opponent_deck.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;
import 'package:gwent_content/gwent_content.dart' as content;

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/fakes.dart';

void main() {
  late FakeDeckRulesSource rules;

  setUp(() => rules = FakeDeckRulesSource());

  ChooseOpponentDeck choose(int seed) => ChooseOpponentDeck(rules, FixedSeedGenerator(seed));

  test('фракция бота выбирается случайно из всех фракций пакета, зеркальная партия возможна', () async {
    final factions = <String>{};
    for (var seed = 0; seed < 40; seed++) {
      factions.add((await choose(seed)(BotDifficulty.normal)).factionId);
    }

    expect(factions, {Small.skellige, Small.monsters});
  });

  test('колода бота годна для партии на любом уровне', () async {
    for (final difficulty in BotDifficulty.values) {
      for (var seed = 0; seed < 20; seed++) {
        final deck = await choose(seed)(difficulty);
        expect(rules.rules.check(deck), isEmpty, reason: '${difficulty.name}, сид $seed');
      }
    }
  });

  test('с тем же сидом колода та же, с другим сидом набор меняется', () async {
    final decks = {for (var seed = 0; seed < 30; seed++) (await choose(seed)(BotDifficulty.normal)).cards.toString()};

    expect(await choose(7)(BotDifficulty.hard), await choose(7)(BotDifficulty.hard));
    expect(decks.length, greaterThan(1));
  });

  test('колода бота не пишется в хранилище: у неё свой идентификатор', () async {
    expect((await choose(1)(BotDifficulty.easy)).id, 'bot-opponent');
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

    await expectLater(choose(1)(BotDifficulty.normal), throwsA(isA<NotADeckFactionException>()));
  });
}
