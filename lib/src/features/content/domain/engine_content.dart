import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent_content/gwent_content.dart' as content;
import 'package:gwent_engine/gwent_engine.dart';

/// Что умеет движок приложения: версия, эффекты карт и лидеров и перки фракций.
///
/// Перки движок хранит перечислением [FactionPerk], а не строками, поэтому их ключи добавляются здесь. Проворство
/// в движке не способность, а размещение карты ([UnitPlacement.agile]), но играет его движок, поэтому ключ тоже здесь.
final content.EngineCapabilities engineCapabilities = content.EngineCapabilities(
  engineVersion: engineVersion,
  knownEffects: {...knownEffects, content.EffectKey.agile.key, for (final perk in _perks.values) perk.effect.key},
);

/// Переводит проверенный пакет контента в справочник и параметры движка.
///
/// Пакет уже прошёл загрузчик (`ContentPackLoader`) с [engineCapabilities], поэтому эффекты и параметры известны.
/// Здесь ловится только то, что формат пакета допускает, а движок нет: неизвестная фракция, эффект не того вида
/// карты, расхождение признака фракции колоды, перк фракции, который движок не реализует или реализует с другими
/// числами (`PerkNumbers`).
GameContentResult mapContentToEngine(content.ContentPack pack) {
  final mapper = _Mapper(pack.rules);
  final factions = mapper.factions();
  final cards = [
    for (final card in pack.rules.squadCards) ?mapper.unit(card, factions),
    for (final card in pack.rules.specialCards) ?mapper.special(card, factions),
  ];
  final leaders = [for (final card in pack.rules.leaderCards) ?mapper.leader(card, factions)];
  if (mapper.issues.isNotEmpty) return GameContentRejected(mapper.issues);
  return GameContentReady(
    GameContent(
      pack: pack,
      catalog: InMemoryCardCatalog(cards: cards, leaders: leaders),
      rules: _rules(pack.rules.gameRules),
      factions: factions,
    ),
  );
}

/// Перк движка: эффект пакета и числа, которые движок использует.
typedef _Perk = ({content.EffectKey effect, Map<String, int> params});

/// Перки фракций движка (раздел 11 правил) и их параметры в движке.
const Map<FactionPerk, _Perk> _perks = {
  FactionPerk.drawOnRoundWin: (
    effect: content.EffectKey.drawOnRoundWin,
    params: {'count': PerkNumbers.northernRealmsDraw},
  ),
  FactionPerk.winTies: (effect: content.EffectKey.winOnTie, params: {}),
  FactionPerk.keepRandomUnit: (
    effect: content.EffectKey.keepRandomUnit,
    params: {'count': PerkNumbers.monstersKeptUnits},
  ),
  FactionPerk.chooseFirstPlayer: (effect: content.EffectKey.chooseFirstPlayer, params: {}),
  FactionPerk.reviveInFinalRound: (
    effect: content.EffectKey.reviveRandomUnits,
    params: {'count': PerkNumbers.skelligeRevivedUnits, 'round': PerkNumbers.skelligeReviveRound},
  ),
};

/// Фракции движка по машинному ключу фракции пакета.
const Map<String, Faction> _factionKeys = {
  'common': Faction.neutral,
  'northern_realms': Faction.northernRealms,
  'nilfgaardian_empire': Faction.nilfgaard,
  'monsters': Faction.monsters,
  'scoia_tael': Faction.scoiatael,
  'skellige': Faction.skellige,
};

GameRules _rules(content.GameRules rules) => GameRules(
  startingHand: rules.startingHandSize,
  redrawLimit: rules.maxRedraws,
  crystals: rules.crystals,
  minUnitCards: rules.minSquadCards,
  maxSpecialCards: rules.maxSpecialCards,
);

Row _row(content.CombatRow row) => switch (row) {
  content.CombatRow.melee => Row.melee,
  content.CombatRow.ranged => Row.ranged,
  content.CombatRow.siege => Row.siege,
};

UnitPlacement _placement(content.ZoneKey zone) => switch (zone) {
  content.ZoneKey.melee => UnitPlacement.melee,
  content.ZoneKey.ranged => UnitPlacement.ranged,
  content.ZoneKey.siege => UnitPlacement.siege,
  content.ZoneKey.agile => UnitPlacement.agile,
};

/// Сопоставление одного пакета; проблемы копятся в [issues], чтобы показать их все сразу.
final class _Mapper {
  _Mapper(this._rules);

  final content.PackRules _rules;
  final List<content.ValidationIssue> issues = [];

  void _issue(String path, String code, String message) => issues.add(
    content.ValidationIssue(level: content.ValidationLevel.compatibility, code: code, path: path, message: message),
  );

  /// Фракции движка по UUID; заодно проверяет, что перк каждой фракции движок реализует с теми же числами.
  Map<String, Faction> factions() {
    final result = <String, Faction>{};
    for (final (index, fraction) in _rules.fractions.indexed) {
      final path = 'fractions[$index]';
      final faction = _factionKeys[fraction.key];
      if (faction == null) {
        _issue('$path.key', 'unknown_faction', 'движок не знает фракцию ${fraction.key}');
        continue;
      }
      result[fraction.id] = faction;
      if (fraction.isDeck != faction.isDeckFaction) {
        _issue(
          '$path.is_deck',
          'deck_faction_mismatch',
          'у движка фракция ${faction.name} с is_deck ${faction.isDeckFaction}',
        );
      }
      _checkPerk(path, faction, _rules.perkOfFraction(fraction));
    }
    return result;
  }

  void _checkPerk(String path, Faction faction, content.ResolvedEffect? perk) {
    final expected = _perks[faction.perk];
    if (expected == null && perk == null) return;
    final matches =
        expected != null &&
        perk != null &&
        perk.effect == expected.effect &&
        perk.params.length == expected.params.length &&
        expected.params.entries.every(
          (param) => switch (perk.params[param.key]) {
            content.CountParam(:final value) => value == param.value,
            _ => false,
          },
        );
    if (!matches) {
      final wanted = expected == null ? 'без перка' : '${expected.effect.key} ${expected.params}';
      _issue('$path.ability_id', 'unsupported_perk', 'движок играет фракцию ${faction.name} $wanted');
    }
  }

  Faction? _faction(String path, String fractionId, Map<String, Faction> factions) {
    final faction = factions[fractionId];
    if (faction == null) _issue('$path.fraction_id', 'unknown_faction', 'фракция $fractionId не сопоставлена');
    return faction;
  }

  UnitCardDefinition? unit(content.SquadCard card, Map<String, Faction> factions) {
    final path = 'squad_cards.${card.id}';
    final before = issues.length;
    final faction = _faction(path, card.fractionId, factions);
    final zone = _rules.zonesById[card.zoneId];
    if (zone == null) _issue('$path.zone_id', 'unknown_zone', 'зона ${card.zoneId} не найдена');
    final effect = _rules.effectOfSquadCard(card);
    final ability = effect == null ? null : _unitAbility(path, effect);
    if (faction == null || zone == null || issues.length > before) return null;
    return UnitCardDefinition(
      id: CardId(card.id),
      faction: faction,
      copies: card.count,
      placement: _placement(zone.key),
      strength: card.strength,
      isHero: card.isHero,
      ability: ability,
    );
  }

  /// Способность отряда; у проворства `null`, потому что это размещение карты, а не способность.
  UnitAbility? _unitAbility(String path, content.ResolvedEffect effect) => switch (effect.effect) {
    content.EffectKey.spy => SpyAbility(draw: effect.count('draw')),
    content.EffectKey.medic => const MedicAbility(),
    content.EffectKey.muster => MusterAbility([for (final id in effect.cardIds('summons')) CardId(id)]),
    content.EffectKey.tightBond => const TightBondAbility(),
    content.EffectKey.moraleBoost => const MoraleBoostAbility(),
    content.EffectKey.commanderHorn => const UnitHornAbility(),
    content.EffectKey.scorchRow => ScorchRowAbility(_row(effect.row('row')), threshold: effect.count('threshold')),
    content.EffectKey.scorch => const ScorchAllAbility(),
    content.EffectKey.bait => BaitAbility(CardId(effect.cardId('summons'))),
    content.EffectKey.berserk => BerserkAbility(CardId(effect.cardId('transform_to'))),
    content.EffectKey.mardroeme => const MardremAuraAbility(),
    content.EffectKey.agile => null,
    content.EffectKey.weather ||
    content.EffectKey.clearWeather ||
    content.EffectKey.decoy ||
    content.EffectKey.playWeatherFromDeck ||
    content.EffectKey.playAnyWeatherFromDeck ||
    content.EffectKey.leaderHorn ||
    content.EffectKey.revealOpponentHand ||
    content.EffectKey.disableOpponentLeader ||
    content.EffectKey.takeFromOpponentDiscard ||
    content.EffectKey.randomMedic ||
    content.EffectKey.returnFromDiscard ||
    content.EffectKey.discardAndDraw ||
    content.EffectKey.doubleSpies ||
    content.EffectKey.extraStartingCard ||
    content.EffectKey.optimizeAgile ||
    content.EffectKey.halveWeather ||
    content.EffectKey.shuffleDiscardsIntoDecks ||
    content.EffectKey.drawOnRoundWin ||
    content.EffectKey.winOnTie ||
    content.EffectKey.keepRandomUnit ||
    content.EffectKey.chooseFirstPlayer ||
    content.EffectKey.reviveRandomUnits => _notApplicable<UnitAbility>(path, effect, 'отряда'),
  };

  SpecialCardDefinition? special(content.SpecialCard card, Map<String, Faction> factions) {
    final path = 'special_cards.${card.id}';
    final faction = _faction(path, card.fractionId, factions);
    final ability = _specialAbility(path, _rules.effectOfSpecialCard(card));
    if (faction == null || ability == null) return null;
    return SpecialCardDefinition(id: CardId(card.id), faction: faction, copies: card.count, ability: ability);
  }

  SpecialAbility? _specialAbility(String path, content.ResolvedEffect effect) => switch (effect.effect) {
    content.EffectKey.weather => WeatherAbility({for (final row in effect.rows('rows')) _row(row)}),
    content.EffectKey.clearWeather => const ClearWeatherAbility(),
    content.EffectKey.commanderHorn => const HornCardAbility(),
    content.EffectKey.decoy => const DecoyAbility(),
    content.EffectKey.scorch => const ScorchAbility(),
    content.EffectKey.mardroeme => const MardremCardAbility(),
    content.EffectKey.spy ||
    content.EffectKey.medic ||
    content.EffectKey.muster ||
    content.EffectKey.tightBond ||
    content.EffectKey.moraleBoost ||
    content.EffectKey.scorchRow ||
    content.EffectKey.bait ||
    content.EffectKey.berserk ||
    content.EffectKey.agile ||
    content.EffectKey.playWeatherFromDeck ||
    content.EffectKey.playAnyWeatherFromDeck ||
    content.EffectKey.leaderHorn ||
    content.EffectKey.revealOpponentHand ||
    content.EffectKey.disableOpponentLeader ||
    content.EffectKey.takeFromOpponentDiscard ||
    content.EffectKey.randomMedic ||
    content.EffectKey.returnFromDiscard ||
    content.EffectKey.discardAndDraw ||
    content.EffectKey.doubleSpies ||
    content.EffectKey.extraStartingCard ||
    content.EffectKey.optimizeAgile ||
    content.EffectKey.halveWeather ||
    content.EffectKey.shuffleDiscardsIntoDecks ||
    content.EffectKey.drawOnRoundWin ||
    content.EffectKey.winOnTie ||
    content.EffectKey.keepRandomUnit ||
    content.EffectKey.chooseFirstPlayer ||
    content.EffectKey.reviveRandomUnits => _notApplicable<SpecialAbility>(path, effect, 'специальной карты'),
  };

  LeaderDefinition? leader(content.LeaderCard card, Map<String, Faction> factions) {
    final path = 'leader_cards.${card.id}';
    final faction = _faction(path, card.fractionId, factions);
    final ability = _leaderAbility(path, _rules.effectOfLeaderCard(card));
    if (faction == null || ability == null) return null;
    return LeaderDefinition(id: LeaderId(card.id), faction: faction, ability: ability);
  }

  LeaderAbility? _leaderAbility(String path, content.ResolvedEffect effect) => switch (effect.effect) {
    content.EffectKey.playWeatherFromDeck => PlayWeatherFromDeckAbility(CardId(effect.cardId('card_id'))),
    content.EffectKey.playAnyWeatherFromDeck => const PickWeatherFromDeckAbility(),
    content.EffectKey.clearWeather => const ClearAllWeatherAbility(),
    content.EffectKey.leaderHorn => LeaderHornAbility(_row(effect.row('row'))),
    content.EffectKey.scorchRow => ScorchOpponentRowAbility(
      _row(effect.row('row')),
      threshold: effect.count('threshold'),
    ),
    content.EffectKey.revealOpponentHand => RevealOpponentHandAbility(count: effect.count('count')),
    content.EffectKey.disableOpponentLeader => const DisableOpponentLeaderAbility(),
    content.EffectKey.takeFromOpponentDiscard => const TakeFromOpponentDiscardAbility(),
    content.EffectKey.randomMedic => const RandomMedicAbility(),
    content.EffectKey.returnFromDiscard => const ReturnFromDiscardAbility(),
    content.EffectKey.discardAndDraw => DiscardAndTakeFromDeckAbility(
      discard: effect.count('discard'),
      take: effect.count('draw'),
    ),
    content.EffectKey.doubleSpies => const DoubleSpiesAbility(),
    content.EffectKey.extraStartingCard => ExtraStartingCardsAbility(count: effect.count('count')),
    content.EffectKey.optimizeAgile => const OptimizeAgileAbility(),
    content.EffectKey.halveWeather => const HalveWeatherAbility(),
    content.EffectKey.shuffleDiscardsIntoDecks => const ShuffleDiscardsIntoDecksAbility(),
    content.EffectKey.spy ||
    content.EffectKey.medic ||
    content.EffectKey.muster ||
    content.EffectKey.tightBond ||
    content.EffectKey.moraleBoost ||
    content.EffectKey.commanderHorn ||
    content.EffectKey.scorch ||
    content.EffectKey.bait ||
    content.EffectKey.berserk ||
    content.EffectKey.mardroeme ||
    content.EffectKey.agile ||
    content.EffectKey.weather ||
    content.EffectKey.decoy ||
    content.EffectKey.drawOnRoundWin ||
    content.EffectKey.winOnTie ||
    content.EffectKey.keepRandomUnit ||
    content.EffectKey.chooseFirstPlayer ||
    content.EffectKey.reviveRandomUnits => _notApplicable<LeaderAbility>(path, effect, 'лидера'),
  };

  /// Отмечает эффект, который движок не играет у карты этого вида.
  T? _notApplicable<T>(String path, content.ResolvedEffect effect, String kind) {
    _issue(path, 'effect_not_applicable', 'движок не играет эффект ${effect.effect.key} у $kind');
    return null;
  }
}
