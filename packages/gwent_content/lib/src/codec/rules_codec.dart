import 'package:gwent_content/src/codec/decode_result.dart';
import 'package:gwent_content/src/codec/json_reader.dart';
import 'package:gwent_content/src/model/ability.dart';
import 'package:gwent_content/src/model/ability_kind.dart';
import 'package:gwent_content/src/model/effect_key.dart';
import 'package:gwent_content/src/model/fraction.dart';
import 'package:gwent_content/src/model/game_rules.dart';
import 'package:gwent_content/src/model/leader_card.dart';
import 'package:gwent_content/src/model/pack_rules.dart';
import 'package:gwent_content/src/model/special_card.dart';
import 'package:gwent_content/src/model/squad_card.dart';
import 'package:gwent_content/src/model/zone.dart';
import 'package:gwent_content/src/model/zone_key.dart';
import 'package:gwent_content/src/pack_format.dart';
import 'package:gwent_content/src/validation/validation_issue.dart';

final RegExp _fractionKey = RegExp(r'^[a-z][a-z0-9_]*$');

/// Разбирает `pack.json` (уровень «схема»). Эффект, которого формат не знает, это проблема совместимости.
DecodeResult<PackRules> decodeRules(Object? json) {
  final r = JsonReader(rulesFileName);
  final root = r.object(json, r'$', required: _tables);
  List<T> table<T>(String name, T Function(Object? item, String path) decode) {
    if (!root.containsKey(name)) return const [];
    final items = r.list(root[name], '\$.$name');
    return [for (var i = 0; i < items.length; i++) decode(items[i], '\$.$name[$i]')];
  }

  final rules = PackRules(
    gameRules: root.containsKey(_gameRulesKey)
        ? _gameRules(r, root[_gameRulesKey], '\$.$_gameRulesKey')
        : const GameRules(crystals: 1, startingHandSize: 1, maxRedraws: 0, minSquadCards: 1, maxSpecialCards: 0),
    zones: table('zones', (item, path) => _zone(r, item, path)),
    fractions: table('fractions', (item, path) => _fraction(r, item, path)),
    fractionAbilities: table('fraction_abilities', (item, path) => _ability(r, item, path, AbilityKind.fraction)),
    squadAbilities: table('squad_abilities', (item, path) => _ability(r, item, path, AbilityKind.squad)),
    specialAbilities: table('special_abilities', (item, path) => _ability(r, item, path, AbilityKind.special)),
    leaderAbilities: table('leader_abilities', (item, path) => _ability(r, item, path, AbilityKind.leader)),
    squadCards: table('squad_cards', (item, path) => _squadCard(r, item, path)),
    specialCards: table('special_cards', (item, path) => _specialCard(r, item, path)),
    leaderCards: table('leader_cards', (item, path) => _leaderCard(r, item, path)),
  );
  return r.issues.isEmpty ? Decoded(rules) : DecodeFailed(r.issues);
}

/// Записывает таблицы правил в JSON (`pack.json`), который [decodeRules] читает обратно без потерь.
Map<String, Object?> encodeRules(PackRules rules) => {
  _gameRulesKey: {
    'crystals': rules.gameRules.crystals,
    'starting_hand_size': rules.gameRules.startingHandSize,
    'max_redraws': rules.gameRules.maxRedraws,
    'min_squad_cards': rules.gameRules.minSquadCards,
    'max_special_cards': rules.gameRules.maxSpecialCards,
  },
  'zones': [
    for (final zone in rules.zones) {'id': zone.id, 'key': zone.key.key, 'name_key': zone.nameKey},
  ],
  'fractions': [
    for (final fraction in rules.fractions)
      {
        'id': fraction.id,
        'key': fraction.key,
        'is_deck': fraction.isDeck,
        'ability_id': fraction.abilityId,
        'name_key': fraction.nameKey,
      },
  ],
  'fraction_abilities': rules.fractionAbilities.map(_encodeAbility).toList(),
  'squad_abilities': rules.squadAbilities.map(_encodeAbility).toList(),
  'special_abilities': rules.specialAbilities.map(_encodeAbility).toList(),
  'leader_abilities': rules.leaderAbilities.map(_encodeAbility).toList(),
  'squad_cards': [
    for (final card in rules.squadCards)
      {
        'id': card.id,
        'fraction_id': card.fractionId,
        'zone_id': card.zoneId,
        'strength': card.strength,
        'is_hero': card.isHero,
        'count': card.count,
        'ability_id': card.abilityId,
        'ability_params': card.abilityParams,
        'name_key': card.nameKey,
        'description_key': card.descriptionKey,
      },
  ],
  'special_cards': [
    for (final card in rules.specialCards)
      {
        'id': card.id,
        'fraction_id': card.fractionId,
        'ability_id': card.abilityId,
        'ability_params': card.abilityParams,
        'count': card.count,
        'name_key': card.nameKey,
        'description_key': card.descriptionKey,
      },
  ],
  'leader_cards': [
    for (final card in rules.leaderCards)
      {
        'id': card.id,
        'fraction_id': card.fractionId,
        'ability_id': card.abilityId,
        'ability_params': card.abilityParams,
        'name_key': card.nameKey,
        'description_key': card.descriptionKey,
      },
  ],
};

const String _gameRulesKey = 'game_rules';

const Set<String> _tables = {
  _gameRulesKey,
  'zones',
  'fractions',
  'fraction_abilities',
  'squad_abilities',
  'special_abilities',
  'leader_abilities',
  'squad_cards',
  'special_cards',
  'leader_cards',
};

GameRules _gameRules(JsonReader r, Object? value, String path) {
  final json = r.object(
    value,
    path,
    required: const {'crystals', 'starting_hand_size', 'max_redraws', 'min_squad_cards', 'max_special_cards'},
  );
  return GameRules(
    crystals: r.integer(json, 'crystals', path, min: 1),
    startingHandSize: r.integer(json, 'starting_hand_size', path, min: 1),
    maxRedraws: r.integer(json, 'max_redraws', path, min: 0),
    minSquadCards: r.integer(json, 'min_squad_cards', path, min: 1),
    maxSpecialCards: r.integer(json, 'max_special_cards', path, min: 0),
  );
}

Zone _zone(JsonReader r, Object? value, String path) {
  final json = r.object(value, path, required: const {'id', 'key', 'name_key'});
  final key = r.string(json, 'key', path);
  final zoneKey = ZoneKey.fromKey(key);
  if (key.isNotEmpty && zoneKey == null) {
    r.error('$path.key', 'invalid_value', 'ключ зоны должен быть одним из: ${ZoneKey.values.map((z) => z.key)}');
  }
  return Zone(id: r.uuid(json, 'id', path), key: zoneKey ?? ZoneKey.melee, nameKey: r.string(json, 'name_key', path));
}

Fraction _fraction(JsonReader r, Object? value, String path) {
  final json = r.object(value, path, required: const {'id', 'key', 'is_deck', 'ability_id', 'name_key'});
  return Fraction(
    id: r.uuid(json, 'id', path),
    key: r.matching(json, 'key', path, _fractionKey, 'ключ латиницей в нижнем регистре: [a-z][a-z0-9_]*'),
    isDeck: r.boolean(json, 'is_deck', path),
    abilityId: r.nullableUuid(json, 'ability_id', path),
    nameKey: r.string(json, 'name_key', path),
  );
}

Ability _ability(JsonReader r, Object? value, String path, AbilityKind kind) {
  final named = kind == AbilityKind.squad || kind == AbilityKind.special;
  final json = r.object(
    value,
    path,
    required: {'id', 'effect', 'params', 'description_key', if (named) 'name_key'},
  );
  final effectKey = r.string(json, 'effect', path);
  final effect = EffectKey.fromKey(effectKey);
  if (effectKey.isNotEmpty && effect == null) {
    r.error(
      '$path.effect',
      'unknown_effect',
      'эффект $effectKey неизвестен формату пакета $packFormatVersion',
      level: ValidationLevel.compatibility,
    );
  } else if (effect != null && !effect.kinds.contains(kind)) {
    r.error('$path.effect', 'effect_not_allowed', 'эффект $effectKey недопустим в таблице ${kind.name}');
  }
  return Ability(
    id: r.uuid(json, 'id', path),
    effect: effect ?? EffectKey.medic,
    params: r.params(json, 'params', path),
    nameKey: named ? r.string(json, 'name_key', path) : null,
    descriptionKey: r.string(json, 'description_key', path),
  );
}

SquadCard _squadCard(JsonReader r, Object? value, String path) {
  final json = r.object(
    value,
    path,
    required: const {
      'id',
      'fraction_id',
      'zone_id',
      'strength',
      'is_hero',
      'count',
      'ability_id',
      'ability_params',
      'name_key',
      'description_key',
    },
  );
  final abilityId = r.nullableUuid(json, 'ability_id', path);
  final abilityParams = r.params(json, 'ability_params', path);
  if (abilityId == null && abilityParams.isNotEmpty) {
    r.error('$path.ability_params', 'params_without_ability', 'у карты без способности параметры должны быть пусты');
  }
  return SquadCard(
    id: r.uuid(json, 'id', path),
    fractionId: r.uuid(json, 'fraction_id', path),
    zoneId: r.uuid(json, 'zone_id', path),
    strength: r.integer(json, 'strength', path, min: 0),
    isHero: r.boolean(json, 'is_hero', path),
    count: r.integer(json, 'count', path, min: 0),
    abilityId: abilityId,
    abilityParams: abilityParams,
    nameKey: r.string(json, 'name_key', path),
    descriptionKey: r.string(json, 'description_key', path),
  );
}

SpecialCard _specialCard(JsonReader r, Object? value, String path) {
  final json = r.object(
    value,
    path,
    required: const {'id', 'fraction_id', 'ability_id', 'ability_params', 'count', 'name_key', 'description_key'},
  );
  return SpecialCard(
    id: r.uuid(json, 'id', path),
    fractionId: r.uuid(json, 'fraction_id', path),
    abilityId: r.uuid(json, 'ability_id', path),
    abilityParams: r.params(json, 'ability_params', path),
    count: r.integer(json, 'count', path, min: 1),
    nameKey: r.string(json, 'name_key', path),
    descriptionKey: r.string(json, 'description_key', path),
  );
}

LeaderCard _leaderCard(JsonReader r, Object? value, String path) {
  final json = r.object(
    value,
    path,
    required: const {'id', 'fraction_id', 'ability_id', 'ability_params', 'name_key', 'description_key'},
  );
  return LeaderCard(
    id: r.uuid(json, 'id', path),
    fractionId: r.uuid(json, 'fraction_id', path),
    abilityId: r.uuid(json, 'ability_id', path),
    abilityParams: r.params(json, 'ability_params', path),
    nameKey: r.string(json, 'name_key', path),
    descriptionKey: r.string(json, 'description_key', path),
  );
}

Map<String, Object?> _encodeAbility(Ability ability) => {
  'id': ability.id,
  'effect': ability.effect.key,
  'params': ability.params,
  'name_key': ?ability.nameKey,
  'description_key': ability.descriptionKey,
};
