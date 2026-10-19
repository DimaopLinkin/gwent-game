import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_card.dart' show DeckDraft;
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/match/domain/bot_deck_builder.dart';
import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart' show CardId, SeededRng;

/// Сборка колоды бота на настоящем пакете карт.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeckRules rules;
  late BotDeckBuilder builder;

  setUpAll(() async {
    rules = await GameContentDeckRulesSource(LoadGameContent(AssetContentSource.basePack(rootBundle))).load();
    builder = BotDeckBuilder(rules);
  });

  const seeds = 30;

  Deck build(String factionId, BotDifficulty difficulty, int seed) =>
      builder.build(factionId, difficulty, SeededRng(seed));

  /// Средняя оценка отряда в колоде (по оценкам бота): особые карты не в счёт, их число зависит от уровня.
  double quality(Deck deck) {
    final values = CardValues(rules.catalog, const GreedyBotSettings());
    var total = 0;
    var count = 0;
    for (final MapEntry(key: id, value: copies) in deck.cards.entries) {
      if (!rules.cardsById[id]!.isUnit) continue;
      total += values.worth(CardId(id)) * copies;
      count += copies;
    }
    return total / count;
  }

  test('колода бота годна для партии на всех уровнях и фракциях', () {
    for (final faction in rules.deckFactions) {
      for (final difficulty in BotDifficulty.values) {
        for (var seed = 0; seed < seeds; seed++) {
          final deck = build(faction.id, difficulty, seed);
          expect(rules.check(deck), isEmpty, reason: '${faction.id}, ${difficulty.name}, сид $seed');
          expect(deck.factionId, faction.id);
          // Не стартовая колода фракции, на которую сборка падает при ошибке: в ней все отряды коллекции.
          final stats = rules.statsOf(DeckDraft.of(deck));
          expect(stats.units, inInclusiveRange(rules.gameRules.minUnitCards, rules.gameRules.minUnitCards + 8));
        }
      }
    }
  });

  test('чем выше уровень, тем в среднем сильнее отряды колоды', () {
    for (final faction in rules.deckFactions) {
      final averages = [
        for (final difficulty in BotDifficulty.values)
          [
                for (var seed = 0; seed < seeds; seed++) quality(build(faction.id, difficulty, seed)),
              ].reduce((a, b) => a + b) /
              seeds,
      ];
      expect(averages[0], lessThan(averages[1]), reason: '${faction.id}: лёгкий слабее нормального $averages');
      expect(averages[1], lessThan(averages[2]), reason: '${faction.id}: нормальный слабее тяжёлого $averages');
      expect(averages[2], lessThan(averages[3]), reason: '${faction.id}: тяжёлый слабее «НА СМЕРТЬ!» $averages');
    }
  });

  test('колода одного уровня каждый раз другая, а один сид даёт одну колоду', () {
    final faction = rules.deckFactions.first.id;
    for (final difficulty in BotDifficulty.values) {
      final decks = {for (var seed = 0; seed < seeds; seed++) build(faction, difficulty, seed).cards.toString()};
      expect(decks.length, greaterThan(seeds ~/ 3), reason: difficulty.name);
      expect(build(faction, difficulty, 5), build(faction, difficulty, 5));
    }
  });

  test('даже на «НА СМЕРТЬ!» в колоду не попадает каждый раз один и тот же набор особых карт', () {
    final faction = rules.deckFactions.first.id;
    final specials = {
      for (var seed = 0; seed < seeds; seed++)
        (build(
          faction,
          BotDifficulty.deathMatch,
          seed,
        ).cards.keys.where((id) => rules.cardsById[id]!.isSpecial).toList()..sort()).join(','),
    };
    expect(specials.length, greaterThan(1));
  });
}
