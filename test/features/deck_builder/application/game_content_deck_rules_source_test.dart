import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent_content/gwent_content.dart';

/// Правила колод на настоящем пакете контента из ассетов (`docs/hand`) и настоящем адаптере движка.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final source = GameContentDeckRulesSource(LoadGameContent(AssetContentSource.basePack(rootBundle)));

  test('у каждой фракции с колодой стартовая колода проходит проверку движка', () async {
    final rules = await source.load();

    expect(rules.deckFactions, hasLength(5));
    expect(rules.gameRules.minUnitCards, rules.pack.rules.gameRules.minSquadCards);
    expect(rules.gameRules.maxSpecialCards, rules.pack.rules.gameRules.maxSpecialCards);
    for (final faction in rules.deckFactions) {
      final deck = rules.starterDeck(faction.id, id: faction.key, updatedAt: DateTime.utc(2026, 10, 12));
      expect(rules.check(deck), isEmpty, reason: faction.key);
      expect(deck.name, rules.pack.text(faction.nameKey));
    }
  });

  group('карты фракций и нейтральные', () {
    const geralt = 'a4baf68d-3b98-4455-991e-8e2ca85ea8e8';
    const ciri = '8b6ec53e-6218-42bb-888a-79d26897fdc1';
    const skelligeStorm = '8da9ddd9-b5d9-40d0-96f9-4f6e6440740b';

    test('в стартовой колоде каждой фракции есть все нейтральные отряды, включая Геральта и Цири', () async {
      final rules = await source.load();
      final neutralUnits = [
        for (final card in rules.pack.rules.squadCards)
          if (card.count > 0 && !rules.isDeckFaction(card.fractionId)) card,
      ];

      expect(neutralUnits.map((card) => card.id), containsAll([geralt, ciri]));
      for (final faction in rules.deckFactions) {
        final deck = rules.starterDeck(faction.id, id: faction.key, updatedAt: DateTime.utc(2026, 10, 18));
        for (final card in neutralUnits) {
          expect(deck.cards[card.id], card.count, reason: '${faction.key}: ${card.id}');
        }
        expect(rules.check(deck), isEmpty, reason: faction.key);
      }
    });

    test('Шторм со Скеллиге нейтральный: есть в наборе карт и в стартовой колоде каждой фракции', () async {
      final rules = await source.load();

      for (final faction in rules.deckFactions) {
        final deck = rules.starterDeck(faction.id, id: faction.key, updatedAt: DateTime.utc(2026, 10, 18));
        final collection = rules.collectionFor(faction.id).map((card) => card.id);

        expect(collection, contains(skelligeStorm), reason: 'набор карт ${faction.key}');
        expect(deck.cards, contains(skelligeStorm), reason: 'стартовая колода ${faction.key}');
      }
    });

    test('колода другой фракции со Штормом со Скеллиге проходит проверку', () async {
      final rules = await source.load();
      final northern = rules.deckFactions.firstWhere((faction) => faction.key == 'northern_realms');
      final starter = rules.starterDeck(northern.id, id: 'north', updatedAt: DateTime.utc(2026, 10, 18));
      final deck = starter.copyWith(cards: {...starter.cards, skelligeStorm: 3});

      expect(rules.check(deck), isEmpty);
    });
  });

  test('повторная загрузка отдаёт те же правила', () async {
    expect(identical(await source.load(), await source.load()), isTrue);
  });

  test('пакет не прошёл проверку: DeckRulesUnavailableException с проблемами', () async {
    final broken = GameContentDeckRulesSource(LoadGameContent(InMemoryContentSource(const {})));

    await expectLater(
      broken.load(),
      throwsA(isA<DeckRulesUnavailableException>().having((e) => e.issues, 'issues', isNotEmpty)),
    );
  });
}
