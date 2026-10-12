import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/engine_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent_content/gwent_content.dart' as content;
import 'package:gwent_engine/gwent_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late content.ContentPack pack;

  setUpAll(() async {
    final result = await content.ContentPackLoader(
      engine: engineCapabilities,
    ).load(AssetContentSource.basePack(rootBundle));
    if (result case content.PackRejected(:final issues)) fail(issues.join('\n'));
    pack = (result as content.PackLoaded).pack;
  });

  GameContent ready(GameContentResult result) => switch (result) {
    GameContentReady(:final content) => content,
    GameContentRejected(:final issues) => fail(issues.join('\n')),
  };

  test('возможности движка: все эффекты карт и лидеров и перки фракций', () {
    expect(engineCapabilities.engineVersion, engineVersion);
    expect(engineCapabilities.knownEffects, containsAll(knownEffects));
    expect(engineCapabilities.knownEffects, {for (final effect in content.EffectKey.values) effect.key}.toSet());
  });

  group('базовый пакет', () {
    test('каждая карта, лидер и фракция попадают в справочник движка', () {
      final game = ready(mapContentToEngine(pack));
      for (final card in pack.rules.squadCards) {
        expect(game.catalog.card(CardId(card.id)), isA<UnitCardDefinition>(), reason: card.id);
      }
      for (final card in pack.rules.specialCards) {
        expect(game.catalog.card(CardId(card.id)), isA<SpecialCardDefinition>(), reason: card.id);
      }
      for (final card in pack.rules.leaderCards) {
        expect(game.catalog.leader(LeaderId(card.id)), isNotNull, reason: card.id);
      }
      expect(game.factions.values.toSet(), Faction.values.toSet());
    });

    test('параметры партии берутся из таблицы game_rules', () {
      final rules = pack.rules.gameRules;
      expect(
        ready(mapContentToEngine(pack)).rules,
        GameRules(
          startingHand: rules.startingHandSize,
          redrawLimit: rules.maxRedraws,
          crystals: rules.crystals,
          minUnitCards: rules.minSquadCards,
          maxSpecialCards: rules.maxSpecialCards,
        ),
      );
    });

    test('способности и размещение переносятся с параметрами карты', () {
      final game = ready(mapContentToEngine(pack));
      final units = [
        for (final card in pack.rules.squadCards) game.catalog.card(CardId(card.id))! as UnitCardDefinition,
      ];
      final specials = [
        for (final card in pack.rules.specialCards) game.catalog.card(CardId(card.id))! as SpecialCardDefinition,
      ];
      final leaders = [for (final card in pack.rules.leaderCards) game.catalog.leader(LeaderId(card.id))!];

      expect(units.where((unit) => unit.placement == UnitPlacement.agile), isNotEmpty);
      expect(units.where((unit) => unit.isHero), isNotEmpty);
      expect(units.where((unit) => unit.isCreated), isNotEmpty);
      // Каждая способность отряда и спецкарты есть в данных: ни один эффект не потерялся при переводе.
      expect({for (final unit in units) ?unit.ability?.runtimeType}, hasLength(11));
      expect({for (final special in specials) special.ability.runtimeType}, hasLength(6));
      expect({for (final leader in leaders) leader.ability.runtimeType}, hasLength(16));
      for (final unit in units) {
        switch (unit.ability) {
          case MusterAbility(:final summons):
            expect(summons, everyElement(predicate<CardId>((id) => game.catalog.card(id) != null)));
          case BaitAbility(:final summon):
            expect(game.catalog.card(summon), isA<UnitCardDefinition>());
          case BerserkAbility(:final transformsInto):
            expect(game.catalog.card(transformsInto), isA<UnitCardDefinition>());
          case _:
        }
      }
    });

    test('каждый лидер начинает партию с колодой из карт своей фракции и нейтральных', () {
      final game = ready(mapContentToEngine(pack));
      final engine = GwentEngine(game.catalog, rules: game.rules);
      final decks = {
        for (final leader in pack.rules.leaderCards)
          leader.id: _fullDeck(pack.rules, game, LeaderId(leader.id), game.factions[leader.fractionId]!),
      };
      final skellige = decks.entries.firstWhere(
        (deck) => game.factions[_leaderFraction(pack, deck.key)] == Faction.skellige,
      );
      for (final MapEntry(key: leaderId, value: deck) in decks.entries) {
        expect(engine.validateDeck(deck), isEmpty, reason: leaderId);
        final result = engine.start(MatchSetup(one: deck, two: skellige.value, rng: const SeededRng(7)));
        expect(result, isA<Accepted>(), reason: leaderId);
      }
    });
  });

  group('пакет, который движок не играет', () {
    test('неизвестная фракция', () {
      final fractions = [
        for (final fraction in pack.rules.fractions)
          fraction.key == 'monsters' ? _fraction(fraction, key: 'redania') : fraction,
      ];
      expect(_issueCodes(mapContentToEngine(_withRules(pack, fractions: fractions))), contains('unknown_faction'));
    });

    test('перк фракции с числами, которых нет в движке', () {
      final abilities = [
        for (final ability in pack.rules.fractionAbilities)
          ability.effect == content.EffectKey.reviveRandomUnits
              ? content.Ability(
                  id: ability.id,
                  effect: ability.effect,
                  params: const {'count': 3, 'round': 3},
                  nameKey: ability.nameKey,
                  descriptionKey: ability.descriptionKey,
                )
              : ability,
      ];
      final result = mapContentToEngine(_withRules(pack, fractionAbilities: abilities));
      expect(result, isA<GameContentRejected>());
      expect((result as GameContentRejected).issues.single.code, 'unsupported_perk');
      expect(result.issues.single.level, content.ValidationLevel.compatibility);
    });

    test('фракция колоды без перка', () {
      final fractions = [
        for (final fraction in pack.rules.fractions)
          fraction.key == 'skellige' ? _fraction(fraction, dropPerk: true) : fraction,
      ];
      expect(_issueCodes(mapContentToEngine(_withRules(pack, fractions: fractions))), ['unsupported_perk']);
    });
  });
}

/// Колода лидера: все карты отрядов его фракции и нейтральные со всеми копиями и первые специальные карты.
Deck _fullDeck(content.PackRules rules, GameContent game, LeaderId leader, Faction faction) {
  bool fits(String fractionId) => game.factions[fractionId] == faction || game.factions[fractionId] == Faction.neutral;
  final specials = [
    for (final card in rules.specialCards)
      if (fits(card.fractionId))
        for (var i = 0; i < card.count; i++) CardId(card.id),
  ].take(game.rules.maxSpecialCards);
  return Deck(
    leader: leader,
    cards: [
      for (final card in rules.squadCards)
        if (fits(card.fractionId))
          for (var i = 0; i < card.count; i++) CardId(card.id),
      ...specials,
    ],
  );
}

String _leaderFraction(content.ContentPack pack, String leaderId) => pack.rules.leaderCardsById[leaderId]!.fractionId;

List<String> _issueCodes(GameContentResult result) => switch (result) {
  GameContentReady() => const [],
  GameContentRejected(:final issues) => [for (final issue in issues) issue.code],
};

content.Fraction _fraction(content.Fraction fraction, {String? key, bool dropPerk = false}) => content.Fraction(
  id: fraction.id,
  key: key ?? fraction.key,
  isDeck: fraction.isDeck,
  abilityId: dropPerk ? null : fraction.abilityId,
  nameKey: fraction.nameKey,
);

content.ContentPack _withRules(
  content.ContentPack pack, {
  List<content.Fraction>? fractions,
  List<content.Ability>? fractionAbilities,
}) {
  final rules = pack.rules;
  return content.ContentPack(
    manifest: pack.manifest,
    strings: pack.strings,
    rules: content.PackRules(
      gameRules: rules.gameRules,
      zones: rules.zones,
      fractions: fractions ?? rules.fractions,
      fractionAbilities: fractionAbilities ?? rules.fractionAbilities,
      squadAbilities: rules.squadAbilities,
      specialAbilities: rules.specialAbilities,
      leaderAbilities: rules.leaderAbilities,
      squadCards: rules.squadCards,
      specialCards: rules.specialCards,
      leaderCards: rules.leaderCards,
    ),
  );
}
