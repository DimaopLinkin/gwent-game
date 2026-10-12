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
