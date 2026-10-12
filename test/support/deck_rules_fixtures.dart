import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';
import 'package:gwent_content/gwent_content.dart' as content;
import 'package:gwent_engine/gwent_engine.dart' as engine;

/// UUID фракций, лидеров и карт маленького пакета [smallPack]. Условные: настоящие данные в тесте стартовых колод.
abstract final class Small {
  static const String skellige = 'f-skellige';
  static const String monsters = 'f-monsters';
  static const String common = 'f-common';

  static const String crach = 'l-crach';
  static const String bran = 'l-bran';
  static const String eredin = 'l-eredin';

  /// Отряд Скеллиге, 3 копии.
  static const String warrior = 'c-warrior';

  /// Герой Скеллиге, 1 копия.
  static const String cerys = 'c-cerys';

  /// Созданная карта Скеллиге (`count` = 0).
  static const String vildkaarl = 'c-vildkaarl';

  /// Отряд Чудовищ, 3 копии.
  static const String ghoul = 'c-ghoul';

  /// Нейтральный отряд, 1 копия.
  static const String geralt = 'c-geralt';

  /// Нейтральный отряд, 2 копии.
  static const String vesemir = 'c-vesemir';

  /// Специальная карта Скеллиге, 3 копии.
  static const String mardroeme = 's-mardroeme';

  /// Нейтральная погода, 3 копии.
  static const String frost = 's-frost';

  /// Нейтральный рог, 3 копии.
  static const String horn = 's-horn';
}

/// Параметры колоды маленького пакета: не меньше 5 отрядов, не больше 2 специальных карт.
const engine.GameRules smallGameRules = engine.GameRules(minUnitCards: 5, maxSpecialCards: 2);

/// Маленький пакет: две фракции с колодой и нейтральные карты.
final content.ContentPack smallPack = content.ContentPack(
  manifest: content.Manifest(
    formatVersion: 1,
    packId: 'test-pack',
    packVersion: 1,
    minEngineVersion: 1,
    contentHash: 'sha256:test',
    locales: const ['ru'],
    files: const [],
  ),
  rules: content.PackRules(
    gameRules: const content.GameRules(
      crystals: 2,
      startingHandSize: 10,
      maxRedraws: 2,
      minSquadCards: 5,
      maxSpecialCards: 2,
    ),
    zones: const [],
    fractions: [
      _fraction(Small.common, 'common', isDeck: false),
      _fraction(Small.skellige, 'skellige'),
      _fraction(Small.monsters, 'monsters'),
    ],
    fractionAbilities: const [],
    squadAbilities: const [],
    specialAbilities: const [],
    leaderAbilities: const [],
    squadCards: [
      _squad(Small.warrior, Small.skellige, 3),
      _squad(Small.cerys, Small.skellige, 1),
      _squad(Small.vildkaarl, Small.skellige, 0),
      _squad(Small.ghoul, Small.monsters, 3),
      _squad(Small.geralt, Small.common, 1),
      _squad(Small.vesemir, Small.common, 2),
    ],
    specialCards: [
      _special(Small.frost, Small.common),
      _special(Small.mardroeme, Small.skellige),
      _special(Small.horn, Small.common),
    ],
    leaderCards: [
      _leader(Small.eredin, Small.monsters),
      _leader(Small.crach, Small.skellige),
      _leader(Small.bran, Small.skellige),
    ],
  ),
  strings: {
    'ru': content.StringTable(
      locale: 'ru',
      entries: const {'fraction.f-skellige.name': 'Скеллиге', 'fraction.f-monsters.name': 'Чудовища'},
    ),
  },
);

/// Правила маленького пакета.
final DeckRules smallDeckRules = deckRulesFor(smallPack, gameRules: smallGameRules);

/// Правила по пакету [pack] со справочником движка из [testCatalogFor].
DeckRules deckRulesFor(content.ContentPack pack, {engine.GameRules gameRules = const engine.GameRules()}) =>
    DeckRules(pack: pack, catalog: testCatalogFor(pack), gameRules: gameRules);

/// Справочник движка по пакету [pack] для проверки колод.
///
/// Проверке колоды нужны только фракция, число копий и вид карты, поэтому способности здесь заглушки. Настоящее
/// сопоставление пакета с движком делает слой data приложения.
engine.CardCatalog testCatalogFor(content.ContentPack pack) {
  final rules = pack.rules;
  engine.Faction faction(String fractionId) => switch (rules.fractionsById[fractionId]?.key) {
    'northern_realms' => engine.Faction.northernRealms,
    'nilfgaardian_empire' => engine.Faction.nilfgaard,
    'monsters' => engine.Faction.monsters,
    'scoia_tael' => engine.Faction.scoiatael,
    'skellige' => engine.Faction.skellige,
    _ => engine.Faction.neutral,
  };
  return engine.InMemoryCardCatalog(
    cards: [
      for (final card in rules.squadCards)
        engine.UnitCardDefinition(
          id: engine.CardId(card.id),
          faction: faction(card.fractionId),
          copies: card.count,
          placement: engine.UnitPlacement.melee,
          strength: card.strength,
          isHero: card.isHero,
        ),
      for (final card in rules.specialCards)
        engine.SpecialCardDefinition(
          id: engine.CardId(card.id),
          faction: faction(card.fractionId),
          copies: card.count,
          ability: const engine.DecoyAbility(),
        ),
    ],
    leaders: [
      for (final leader in rules.leaderCards)
        engine.LeaderDefinition(
          id: engine.LeaderId(leader.id),
          faction: faction(leader.fractionId),
          ability: const engine.RandomMedicAbility(),
        ),
    ],
  );
}

/// Источник, который отдаёт заданные правила.
final class FakeDeckRulesSource implements DeckRulesSource {
  FakeDeckRulesSource([DeckRules? rules]) : rules = rules ?? smallDeckRules;

  /// Правила, которые отдаёт источник; тест может подменить их, как будто сменился пакет.
  DeckRules rules;

  @override
  Future<DeckRules> load() async => rules;
}

content.Fraction _fraction(String id, String key, {bool isDeck = true}) =>
    content.Fraction(id: id, key: key, isDeck: isDeck, abilityId: null, nameKey: 'fraction.$id.name');

content.SquadCard _squad(String id, String fractionId, int count) => content.SquadCard(
  id: id,
  fractionId: fractionId,
  zoneId: 'z-melee',
  strength: 5,
  isHero: false,
  count: count,
  abilityId: null,
  abilityParams: const {},
  nameKey: 'card.$id.name',
  descriptionKey: 'card.$id.description',
);

content.SpecialCard _special(String id, String fractionId) => content.SpecialCard(
  id: id,
  fractionId: fractionId,
  abilityId: 'a-$id',
  abilityParams: const {},
  count: 3,
  nameKey: 'card.$id.name',
  descriptionKey: 'card.$id.description',
);

content.LeaderCard _leader(String id, String fractionId) => content.LeaderCard(
  id: id,
  fractionId: fractionId,
  abilityId: 'a-$id',
  abilityParams: const {},
  nameKey: 'card.$id.name',
  descriptionKey: 'card.$id.description',
);

/// Годная колода Скеллиге маленького пакета: 5 отрядов и одна погода.
Deck smallSkelligeDeck({
  String id = 'deck-skellige',
  String leaderId = Small.crach,
  Map<String, int> cards = const {Small.warrior: 3, Small.cerys: 1, Small.geralt: 1, Small.frost: 1},
  DateTime? updatedAt,
}) => Deck(
  id: id,
  name: 'Скеллиге',
  factionId: Small.skellige,
  leaderId: leaderId,
  cards: cards,
  updatedAt: updatedAt ?? DateTime.utc(2026, 10, 12),
);
