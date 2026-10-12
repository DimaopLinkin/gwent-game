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

    test('параметры партии берутся из таблицы game_rules поле в поле', () {
      const rules = content.GameRules(
        crystals: 3,
        startingHandSize: 11,
        maxRedraws: 4,
        minSquadCards: 25,
        maxSpecialCards: 7,
      );
      expect(
        ready(mapContentToEngine(_withRules(pack, gameRules: rules))).rules,
        const GameRules(startingHand: 11, redrawLimit: 4, crystals: 3, minUnitCards: 25, maxSpecialCards: 7),
      );
    });

    test('поля каждой карты отряда переносятся без изменений', () {
      final game = ready(mapContentToEngine(pack));
      for (final card in pack.rules.squadCards) {
        final unit = game.catalog.card(CardId(card.id))! as UnitCardDefinition;
        expect(unit.strength, card.strength, reason: card.id);
        expect(unit.copies, card.count, reason: card.id);
        expect(unit.isHero, card.isHero, reason: card.id);
        expect(unit.faction, game.factions[card.fractionId], reason: card.id);
        expect(unit.placement.name, pack.rules.zonesById[card.zoneId]!.key.key, reason: card.id);
      }
      for (final card in pack.rules.specialCards) {
        final special = game.catalog.card(CardId(card.id))! as SpecialCardDefinition;
        expect((special.copies, special.faction), (card.count, game.factions[card.fractionId]), reason: card.id);
      }
      for (final card in pack.rules.leaderCards) {
        expect(game.catalog.leader(LeaderId(card.id))!.faction, game.factions[card.fractionId], reason: card.id);
      }
    });

    test('параметры способностей известных карт', () {
      final game = ready(mapContentToEngine(pack));
      Object? card(String id) => game.catalog.card(CardId(id));
      Object? leader(String id) => game.catalog.leader(LeaderId(id))!.ability;

      // Отряды: Талер, Виллентретенмерт, Корова, Ольгерд фон Эверек, Лютик, Мышовур, Геральт.
      expect((card('4a1311b2-4c5c-47b6-95c6-f5202ba77b53')! as UnitCardDefinition).ability, const SpyAbility());
      expect(
        (card('883e5b44-c2da-4595-8e1e-f1969e32ec65')! as UnitCardDefinition).ability,
        const ScorchRowAbility(Row.melee),
      );
      expect(
        (card('91dc1d59-32ab-45aa-9bba-52305024daa2')! as UnitCardDefinition).ability,
        const BaitAbility(CardId('98141875-7fe6-4525-94ba-90dc861af750')),
      );
      final olgierd = card('840fbcda-f7c9-4f5e-9248-3479b4c15ae3')! as UnitCardDefinition;
      expect((olgierd.placement, olgierd.ability), (UnitPlacement.agile, const MoraleBoostAbility()));
      expect((card('90d7625b-2f3b-4840-ac21-826a9046df83')! as UnitCardDefinition).ability, const UnitHornAbility());
      final mysovur = card('72c00295-782c-47ba-a3be-e298c90d09dd')! as UnitCardDefinition;
      expect(
        (mysovur.placement, mysovur.isHero, mysovur.ability),
        (
          UnitPlacement.ranged,
          true,
          const MardremAuraAbility(),
        ),
      );
      final geralt = card('a4baf68d-3b98-4455-991e-8e2ca85ea8e8')! as UnitCardDefinition;
      expect((geralt.strength, geralt.isHero, geralt.ability), (15, true, null));

      // Погода: Мороз, Мгла, Ливень, Шторм со Скеллиге.
      Object? weather(String id) => (card(id)! as SpecialCardDefinition).ability;
      expect(weather('c858b281-84d5-410a-9e63-45f9e61d6825'), const WeatherAbility({Row.melee}));
      expect(weather('7da6c359-b0a6-45ff-a8de-f713f398b2b8'), const WeatherAbility({Row.ranged}));
      expect(weather('b60d66ee-d0be-45c1-9b64-890eea79ec85'), const WeatherAbility({Row.siege}));
      expect(weather('8da9ddd9-b5d9-40d0-96f9-4f6e6440740b'), const WeatherAbility({Row.ranged, Row.siege}));
      expect(weather('47d44246-c663-4218-b537-b81929c5caf0'), const HornCardAbility());
      expect(weather('dafeabf0-b94f-4b4e-86d8-21822a8fee06'), const MardremCardAbility());

      // Лидеры: Убийца Оберона, Фольтест Завоеватель, Францеска Прекраснейшая, Фольтест Предводитель Севера.
      expect(leader('953f3df6-00db-4071-961f-ee1644025139'), const DiscardAndTakeFromDeckAbility());
      expect(leader('d8c7de0f-b935-47b6-a32d-2cc1c63326f3'), const LeaderHornAbility(Row.siege));
      expect(leader('f8bbd5cf-e103-4ec1-9213-169c46368cc5'), const LeaderHornAbility(Row.ranged));
      expect(leader('8c2c32b8-804b-45e4-9d8a-c70d28014a12'), const ClearAllWeatherAbility());
    });

    test('ни один вид способности не теряется, ссылки ведут на карты справочника', () {
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
      final result = mapContentToEngine(_withRules(pack, fractions: fractions));
      expect(_issueCodes(result), contains('unknown_faction'));
      final index = pack.rules.fractions.indexWhere((fraction) => fraction.key == 'monsters');
      expect((result as GameContentRejected).issues.first.path, 'fractions[$index].key');
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

    test('нейтральная фракция с перком', () {
      final skellige = pack.rules.fractions.firstWhere((fraction) => fraction.key == 'skellige');
      final fractions = [
        for (final fraction in pack.rules.fractions)
          fraction.key == 'common' ? _fraction(fraction, abilityId: skellige.abilityId) : fraction,
      ];
      expect(_issueCodes(mapContentToEngine(_withRules(pack, fractions: fractions))), ['unsupported_perk']);
    });

    test('признак фракции колоды расходится с движком', () {
      final fractions = [
        for (final fraction in pack.rules.fractions)
          fraction.key == 'common' ? _fraction(fraction, isDeck: true) : fraction,
      ];
      expect(_issueCodes(mapContentToEngine(_withRules(pack, fractions: fractions))), ['deck_faction_mismatch']);
    });

    test('фракция колоды без перка', () {
      final fractions = [
        for (final fraction in pack.rules.fractions)
          fraction.key == 'skellige' ? _fraction(fraction, abilityId: null) : fraction,
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

content.Fraction _fraction(content.Fraction fraction, {String? key, bool? isDeck, Object? abilityId = _keep}) =>
    content.Fraction(
      id: fraction.id,
      key: key ?? fraction.key,
      isDeck: isDeck ?? fraction.isDeck,
      abilityId: identical(abilityId, _keep) ? fraction.abilityId : abilityId as String?,
      nameKey: fraction.nameKey,
    );

/// Значение по умолчанию: поле не меняется (`null` значит «убрать перк»).
const Object _keep = Object();

content.ContentPack _withRules(
  content.ContentPack pack, {
  List<content.Fraction>? fractions,
  List<content.Ability>? fractionAbilities,
  content.GameRules? gameRules,
}) {
  final rules = pack.rules;
  return content.ContentPack(
    manifest: pack.manifest,
    strings: pack.strings,
    rules: content.PackRules(
      gameRules: gameRules ?? rules.gameRules,
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
