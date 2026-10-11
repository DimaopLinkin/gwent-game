import 'package:gwent_content/gwent_content.dart';

/// UUID для тестовых данных: `id(7)` → `00000000-0000-4000-8000-000000000007`.
String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

/// Идентификаторы записей маленького, но полного пакета [samplePackJson].
abstract final class Ids {
  static final String melee = id(1);
  static final String ranged = id(2);
  static final String siege = id(3);
  static final String agile = id(4);
  static final String skellige = id(10);
  static final String neutral = id(11);
  static final String skelligePerk = id(20);
  static final String spyAbility = id(30);
  static final String musterAbility = id(31);
  static final String baitAbility = id(32);
  static final String berserkAbility = id(33);
  static final String scorchRowAbility = id(34);
  static final String tightBondAbility = id(35);
  static final String agileAbility = id(36);
  static final String weatherAbility = id(40);
  static final String leaderAbility = id(50);
  static final String hero = id(100);
  static final String spy = id(101);
  static final String muster = id(102);
  static final String cow = id(103);
  static final String bovine = id(104);
  static final String berserk = id(105);
  static final String bear = id(106);
  static final String scorcher = id(107);
  static final String bond = id(108);
  static final String frost = id(200);
  static final String leader = id(300);
}

/// JSON правил маленького пакета, который проходит все проверки. Каждый вызов возвращает новую изменяемую копию,
/// поэтому тест может испортить её, как ему нужно.
Map<String, Object?> samplePackJson() => {
  'game_rules': {
    'crystals': 2,
    'starting_hand_size': 10,
    'max_redraws': 2,
    'min_squad_cards': 5,
    'max_special_cards': 10,
  },
  'zones': [
    _zone(Ids.melee, 'melee'),
    _zone(Ids.ranged, 'ranged'),
    _zone(Ids.siege, 'siege'),
    _zone(Ids.agile, 'agile'),
  ],
  'fractions': [
    {'id': Ids.skellige, 'key': 'skellige', 'is_deck': true, 'ability_id': Ids.skelligePerk, 'name_key': 'f.s'},
    {'id': Ids.neutral, 'key': 'common', 'is_deck': false, 'ability_id': null, 'name_key': 'f.n'},
  ],
  'fraction_abilities': [
    _ability(Ids.skelligePerk, 'revive_random_units', {'count': 2, 'round': 3}, named: false),
  ],
  'squad_abilities': [
    _ability(Ids.spyAbility, 'spy', {'draw': 2}),
    _ability(Ids.musterAbility, 'muster', {}),
    _ability(Ids.baitAbility, 'bait', {}),
    _ability(Ids.berserkAbility, 'berserk', {}),
    _ability(Ids.scorchRowAbility, 'scorch_row', {'threshold': 10}),
    _ability(Ids.tightBondAbility, 'tight_bond', {}),
    _ability(Ids.agileAbility, 'agile', {}),
  ],
  'special_abilities': [
    _ability(Ids.weatherAbility, 'weather', {
      'rows': ['melee'],
    }),
  ],
  'leader_abilities': [
    _ability(Ids.leaderAbility, 'play_weather_from_deck', {'card_id': Ids.frost}, named: false),
  ],
  'squad_cards': [
    _squad(Ids.hero, Ids.neutral, strength: 15, hero: true),
    _squad(Ids.spy, Ids.neutral, ability: Ids.spyAbility),
    _squad(
      Ids.muster,
      Ids.skellige,
      count: 3,
      ability: Ids.musterAbility,
      params: {
        'summons': [Ids.muster],
      },
    ),
    _squad(Ids.cow, Ids.neutral, ability: Ids.baitAbility, params: {'summons': Ids.bovine}),
    _squad(Ids.bovine, Ids.neutral, count: 0, strength: 8),
    _squad(Ids.berserk, Ids.skellige, ability: Ids.berserkAbility, params: {'transform_to': Ids.bear}),
    _squad(Ids.bear, Ids.skellige, count: 0, strength: 14),
    _squad(Ids.scorcher, Ids.skellige, ability: Ids.scorchRowAbility, params: {'row': 'melee'}),
    _squad(Ids.bond, Ids.skellige, count: 2, zone: Ids.agile, ability: Ids.tightBondAbility),
  ],
  'special_cards': [
    {
      'id': Ids.frost,
      'fraction_id': Ids.neutral,
      'ability_id': Ids.weatherAbility,
      'ability_params': <String, Object?>{},
      'count': 3,
      'name_key': 'sc.frost.name',
      'description_key': 'sc.frost.description',
    },
  ],
  'leader_cards': [
    {
      'id': Ids.leader,
      'fraction_id': Ids.skellige,
      'ability_id': Ids.leaderAbility,
      'ability_params': <String, Object?>{},
      'name_key': 'lc.name',
      'description_key': 'lc.description',
    },
  ],
};

/// Строки для [samplePackJson]: по тексту на каждый ключ.
Map<String, Object?> sampleStringsJson() {
  final keys = <String>{};
  void collect(Object? json) {
    switch (json) {
      case Map<String, Object?>():
        for (final MapEntry(:key, :value) in json.entries) {
          if (key.endsWith('_key') && value is String) keys.add(value);
          collect(value);
        }
      case List<Object?>():
        json.forEach(collect);
    }
  }

  collect(samplePackJson());
  return {for (final key in keys) key: 'текст $key'};
}

/// Записи таблицы [table] из JSON правил [pack] для правки в тестах.
List<Map<String, Object?>> rows(Map<String, Object?> pack, String table) =>
    (pack[table]! as List<Object?>).cast<Map<String, Object?>>();

/// Запись с UUID [recordId] из таблицы [table].
Map<String, Object?> row(Map<String, Object?> pack, String table, String recordId) =>
    rows(pack, table).firstWhere((record) => record['id'] == recordId);

/// Собирает пакет из [rules] и [strings] (JSON) и отдаёт его файлы.
Map<String, List<int>> buildSampleFiles({Map<String, Object?>? rules, Map<String, Object?>? strings}) {
  final decodedRules = decodeRules(rules ?? samplePackJson());
  final decodedStrings = decodeStrings(fallbackLocale, strings ?? sampleStringsJson());
  return buildContentPack(
    identity: sampleIdentity,
    rules: (decodedRules as Decoded<PackRules>).value,
    strings: {fallbackLocale: (decodedStrings as Decoded<StringTable>).value},
  ).files.map((path, bytes) => MapEntry(path, [...bytes]));
}

/// Идентичность тестового пакета.
const PackIdentity sampleIdentity = PackIdentity(packId: 'test-pack', packVersion: 1, minEngineVersion: 1);

/// Движок, который знает все эффекты формата.
final EngineCapabilities fullEngine = EngineCapabilities(
  engineVersion: 1,
  knownEffects: {for (final effect in EffectKey.values) effect.key},
);

Map<String, Object?> _zone(String zoneId, String key) => {'id': zoneId, 'key': key, 'name_key': 'zone.$key'};

Map<String, Object?> _ability(String abilityId, String effect, Map<String, Object?> params, {bool named = true}) => {
  'id': abilityId,
  'effect': effect,
  'params': params,
  if (named) 'name_key': 'ability.$abilityId.name',
  'description_key': 'ability.$abilityId.description',
};

Map<String, Object?> _squad(
  String cardId,
  String fractionId, {
  int strength = 5,
  bool hero = false,
  int count = 1,
  String? zone,
  String? ability,
  Map<String, Object?> params = const {},
}) => {
  'id': cardId,
  'fraction_id': fractionId,
  'zone_id': zone ?? Ids.melee,
  'strength': strength,
  'is_hero': hero,
  'count': count,
  'ability_id': ability,
  'ability_params': Map.of(params),
  'name_key': 'card.$cardId.name',
  'description_key': 'card.$cardId.description',
};
