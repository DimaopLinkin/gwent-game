import 'package:gwent_engine/gwent_engine.dart';

/// Справочник карт для тестов. Это фикстуры, а не данные из `docs/hand`: имена и параметры подобраны
/// под контрольные примеры правил, идентификаторы читаемые.
final CardCatalog catalog = InMemoryCardCatalog(cards: _units.followedBy(_specials), leaders: _leaders);

UnitCardDefinition _unit(
  String id,
  UnitPlacement placement,
  int strength, {
  Faction faction = Faction.neutral,
  int copies = 1,
  bool hero = false,
  UnitAbility? ability,
}) => UnitCardDefinition(
  id: CardId(id),
  faction: faction,
  copies: copies,
  placement: placement,
  strength: strength,
  isHero: hero,
  ability: ability,
);

SpecialCardDefinition _special(String id, SpecialAbility ability, {Faction faction = Faction.neutral}) =>
    SpecialCardDefinition(id: CardId(id), faction: faction, copies: 3, ability: ability);

LeaderDefinition _leader(String id, Faction faction, LeaderAbility ability) =>
    LeaderDefinition(id: LeaderId(id), faction: faction, ability: ability);

const UnitPlacement _melee = UnitPlacement.melee;
const UnitPlacement _ranged = UnitPlacement.ranged;
const UnitPlacement _siege = UnitPlacement.siege;
const UnitPlacement _agile = UnitPlacement.agile;

final List<CardDefinition> _units = [
  // Раздел 8: контрольные примеры силы.
  _unit('blue_stripes', _melee, 4, faction: Faction.northernRealms, copies: 3, ability: const TightBondAbility()),
  _unit('kaedwen_siege', _siege, 1, faction: Faction.northernRealms, copies: 3, ability: const MoraleBoostAbility()),
  _unit('dandelion', _melee, 2, ability: const UnitHornAbility()),
  _unit('vesemir', _melee, 6),
  _unit('vildkaarl', _melee, 14, faction: Faction.skellige, copies: 0, ability: const MoraleBoostAbility()),
  _unit('udalryk', _melee, 4, faction: Faction.skellige),
  _unit('cerys', _melee, 10, faction: Faction.skellige, hero: true, ability: const MusterAbility([CardId('drummond')])),
  _unit('drummond', _melee, 4, faction: Faction.skellige, copies: 3, ability: const TightBondAbility()),
  _unit('mysterious_elf', _melee, 0, faction: Faction.nilfgaard, hero: true, ability: const SpyAbility()),
  _unit('skellen', _melee, 9, faction: Faction.nilfgaard, ability: const SpyAbility()),
  _unit('thaler', _siege, 1, faction: Faction.northernRealms, ability: const SpyAbility()),
  _unit('geralt', _melee, 15, hero: true),
  _unit('yennefer', _ranged, 7, hero: true, ability: const MedicAbility()),
  _unit('banner_medic', _siege, 5, faction: Faction.northernRealms, ability: const MedicAbility()),
  _unit('archer_medic', _ranged, 1, faction: Faction.nilfgaard, copies: 2, ability: const MedicAbility()),
  _unit('arachas', _melee, 4, faction: Faction.monsters, copies: 3, ability: const MusterAbility([CardId('arachas')])),
  _unit('behemoth', _siege, 6, faction: Faction.monsters, ability: const MusterAbility([CardId('arachas')])),
  _unit(
    'nekker',
    _melee,
    2,
    faction: Faction.monsters,
    ability: const MusterAbility([CardId('harpy'), CardId('archer_medic')]),
  ),
  _unit('villentretenmerth', _melee, 7, ability: const ScorchRowAbility(Row.melee)),
  _unit('schirru', _siege, 8, faction: Faction.scoiatael, ability: const ScorchRowAbility(Row.siege)),
  _unit('pirate', _ranged, 6, faction: Faction.skellige, ability: const ScorchAllAbility()),
  _unit('cow', _ranged, 0, ability: const BaitAbility(CardId('bovine'))),
  _unit('bovine', _melee, 8, copies: 0),
  _unit('kambi', _melee, 0, faction: Faction.skellige, ability: const BaitAbility(CardId('heimdall'))),
  _unit('heimdall', _melee, 11, faction: Faction.skellige, copies: 0, hero: true),
  _unit('berserk', _melee, 4, faction: Faction.skellige, ability: const BerserkAbility(CardId('vildkaarl'))),
  _unit(
    'young_berserk',
    _ranged,
    2,
    faction: Faction.skellige,
    copies: 3,
    ability: const BerserkAbility(CardId('young_vildkaarl')),
  ),
  _unit('young_vildkaarl', _ranged, 8, faction: Faction.skellige, copies: 0, ability: const TightBondAbility()),
  _unit('mysovur', _ranged, 8, faction: Faction.skellige, hero: true, ability: const MardremAuraAbility()),
  _unit('elf_skirmisher', _agile, 6, faction: Faction.scoiatael, copies: 3),
  _unit('olaf', _agile, 12, faction: Faction.skellige, ability: const MoraleBoostAbility()),
  _unit('kejran', _agile, 8, faction: Faction.monsters, hero: true, ability: const MoraleBoostAbility()),
  _unit('harpy', _agile, 2, faction: Faction.monsters),
  _unit('poor_infantry', _melee, 1, faction: Faction.northernRealms, copies: 3, ability: const TightBondAbility()),
  _unit('footman', _melee, 3, copies: 10),
  _unit('archer', _ranged, 3, copies: 10),
  _unit('catapult', _siege, 8, faction: Faction.northernRealms, copies: 2),
  _unit('bond_catapult', _siege, 8, faction: Faction.northernRealms, copies: 2, ability: const TightBondAbility()),
  _unit('ghoul', _melee, 1, faction: Faction.monsters, copies: 10),
];

final List<CardDefinition> _specials = [
  _special('frost', const WeatherAbility({Row.melee})),
  _special('fog', const WeatherAbility({Row.ranged})),
  _special('rain', const WeatherAbility({Row.siege})),
  _special('storm', const WeatherAbility({Row.ranged, Row.siege})),
  _special('clear', const ClearWeatherAbility()),
  _special('horn', const HornCardAbility()),
  _special('decoy', const DecoyAbility()),
  _special('scorch', const ScorchAbility()),
  _special('mardrem', const MardremCardAbility(), faction: Faction.skellige),
];

final List<LeaderDefinition> _leaders = [
  _leader('foltest_fog', Faction.northernRealms, const PlayWeatherFromDeckAbility(CardId('fog'))),
  _leader('foltest_clear', Faction.northernRealms, const ClearAllWeatherAbility()),
  _leader('foltest_horn', Faction.northernRealms, const LeaderHornAbility(Row.siege)),
  _leader('foltest_siege_scorch', Faction.northernRealms, const ScorchOpponentRowAbility(Row.siege)),
  _leader('emgyr_reveal', Faction.nilfgaard, const RevealOpponentHandAbility()),
  _leader('emgyr_white_flame', Faction.nilfgaard, const DisableOpponentLeaderAbility()),
  _leader('emgyr_take', Faction.nilfgaard, const TakeFromOpponentDiscardAbility()),
  _leader('emgyr_random_medic', Faction.nilfgaard, const RandomMedicAbility()),
  _leader('eredin_return', Faction.monsters, const ReturnFromDiscardAbility()),
  _leader('eredin_oberon', Faction.monsters, const DiscardAndTakeFromDeckAbility()),
  _leader('eredin_weather', Faction.monsters, const PickWeatherFromDeckAbility()),
  _leader('eredin_spies', Faction.monsters, const DoubleSpiesAbility()),
  _leader('francesca_daisy', Faction.scoiatael, const ExtraStartingCardsAbility()),
  _leader('francesca_agile', Faction.scoiatael, const OptimizeAgileAbility()),
  _leader('francesca_frost', Faction.scoiatael, const PlayWeatherFromDeckAbility(CardId('frost'))),
  _leader('bran', Faction.skellige, const HalveWeatherAbility()),
  _leader('crach', Faction.skellige, const ShuffleDiscardsIntoDecksAbility()),
];

/// Параметры для маленьких тестовых колод.
const GameRules smallDecks = GameRules(minUnitCards: 0);

/// Движок со справочником фикстур.
GwentEngine engineWith({GameRules rules = smallDecks}) => GwentEngine(catalog, rules: rules);

/// Движок по умолчанию для тестов: маленькие колоды разрешены.
final GwentEngine engine = engineWith();
