import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent_content/gwent_content.dart';
import 'package:gwent_engine/gwent_engine.dart' as engine;

import '../../../support/deck_rules_fixtures.dart';

/// Стартовые колоды на настоящем пакете контента из ассетов (`docs/hand`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentPack pack;

  setUpAll(() async {
    final loader = ContentPackLoader(
      engine: EngineCapabilities(engineVersion: 1, knownEffects: {for (final effect in EffectKey.values) effect.key}),
    );
    final result = await loader.load(AssetContentSource.basePack(rootBundle));
    if (result case PackRejected(:final issues)) fail(issues.join('\n'));
    pack = (result as PackLoaded).pack;
  });

  test('параметры колоды движка по умолчанию совпадают с пакетом', () {
    const defaults = engine.GameRules();
    expect(defaults.minUnitCards, pack.rules.gameRules.minSquadCards);
    expect(defaults.maxSpecialCards, pack.rules.gameRules.maxSpecialCards);
  });

  test('у каждой фракции с колодой стартовая колода проходит проверку', () {
    final rules = deckRulesFor(pack);
    expect(rules.deckFactions, hasLength(5));
    for (final faction in rules.deckFactions) {
      final deck = rules.starterDeck(faction.id, id: faction.key, updatedAt: DateTime.utc(2026, 10, 12));
      expect(rules.check(deck), isEmpty, reason: faction.key);
      expect(deck.name, pack.text(faction.nameKey));
    }
  });
}
