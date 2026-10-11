import 'package:gwent_content/src/model/ability.dart';
import 'package:gwent_content/src/model/effect_key.dart';
import 'package:gwent_content/src/model/effect_param.dart';
import 'package:gwent_content/src/model/effect_resolver.dart';
import 'package:gwent_content/src/model/pack_rules.dart';
import 'package:gwent_content/src/model/param_type.dart';
import 'package:gwent_content/src/model/raw_params.dart';
import 'package:gwent_content/src/model/string_table.dart';
import 'package:gwent_content/src/pack_format.dart';
import 'package:gwent_content/src/validation/issue_sink.dart';
import 'package:gwent_content/src/validation/validation_issue.dart';

/// Уровень «ссылки»: UUID и ключи уникальны, каждая ссылка ведёт в нужную таблицу, параметры эффектов
/// складываются и проверяются по описанию эффекта, у каждого ключа строки есть текст на каждом языке
/// и каждый текст кому-то нужен.
List<ValidationIssue> checkReferences(PackRules rules, Map<String, StringTable> strings) {
  final sink = IssueSink(ValidationLevel.references);
  _checkUniqueIds(rules, sink);
  _checkUniqueKeys(rules, sink);

  void ref(String path, String? id, Map<String, Object> table, String tableName) {
    if (id != null && !table.containsKey(id)) sink.add(path, 'unknown_reference', 'нет записи $id в $tableName');
  }

  void effect(String path, Map<String, Ability> abilities, String abilityId, RawParams cardParams) {
    final ability = abilities[abilityId];
    if (ability == null) return;
    final resolved = resolveEffect(ability, cardParams, path: path, onIssue: sink.add);
    if (resolved != null) _checkCardRefs(rules, resolved.effect, resolved.params, path, sink);
  }

  for (final (i, fraction) in rules.fractions.indexed) {
    final path = '\$.fractions[$i]';
    ref('$path.ability_id', fraction.abilityId, rules.fractionAbilitiesById, 'fraction_abilities');
    if (fraction.abilityId case final abilityId?) effect(path, rules.fractionAbilitiesById, abilityId, const {});
  }
  for (final (i, card) in rules.squadCards.indexed) {
    final path = '\$.squad_cards[$i]';
    ref('$path.fraction_id', card.fractionId, rules.fractionsById, 'fractions');
    ref('$path.zone_id', card.zoneId, rules.zonesById, 'zones');
    ref('$path.ability_id', card.abilityId, rules.squadAbilitiesById, 'squad_abilities');
    if (card.abilityId case final abilityId?) effect(path, rules.squadAbilitiesById, abilityId, card.abilityParams);
  }
  for (final (i, card) in rules.specialCards.indexed) {
    final path = '\$.special_cards[$i]';
    ref('$path.fraction_id', card.fractionId, rules.fractionsById, 'fractions');
    ref('$path.ability_id', card.abilityId, rules.specialAbilitiesById, 'special_abilities');
    effect(path, rules.specialAbilitiesById, card.abilityId, card.abilityParams);
  }
  for (final (i, card) in rules.leaderCards.indexed) {
    final path = '\$.leader_cards[$i]';
    ref('$path.fraction_id', card.fractionId, rules.fractionsById, 'fractions');
    ref('$path.ability_id', card.abilityId, rules.leaderAbilitiesById, 'leader_abilities');
    effect(path, rules.leaderAbilitiesById, card.abilityId, card.abilityParams);
  }

  _checkStrings(rules, strings, sink);
  return sink.issues;
}

void _checkUniqueIds(PackRules rules, IssueSink sink) {
  final seen = <String, String>{};
  void visit(String table, Iterable<String> ids) {
    for (final (i, id) in ids.indexed) {
      final path = '\$.$table[$i].id';
      final first = seen[id];
      if (first == null) {
        seen[id] = path;
      } else {
        sink.add(path, 'duplicate_id', 'UUID $id уже занят записью $first');
      }
    }
  }

  visit('zones', rules.zones.map((zone) => zone.id));
  visit('fractions', rules.fractions.map((fraction) => fraction.id));
  visit('fraction_abilities', rules.fractionAbilities.map((ability) => ability.id));
  visit('squad_abilities', rules.squadAbilities.map((ability) => ability.id));
  visit('special_abilities', rules.specialAbilities.map((ability) => ability.id));
  visit('leader_abilities', rules.leaderAbilities.map((ability) => ability.id));
  visit('squad_cards', rules.squadCards.map((card) => card.id));
  visit('special_cards', rules.specialCards.map((card) => card.id));
  visit('leader_cards', rules.leaderCards.map((card) => card.id));
}

void _checkUniqueKeys(PackRules rules, IssueSink sink) {
  void unique(String table, Iterable<String> keys) {
    final seen = <String>{};
    for (final (i, key) in keys.indexed) {
      if (!seen.add(key)) sink.add('\$.$table[$i].key', 'duplicate_key', 'ключ $key уже занят');
    }
  }

  unique('zones', rules.zones.map((zone) => zone.key.key));
  unique('fractions', rules.fractions.map((fraction) => fraction.key));
}

/// Ссылки на карты внутри параметров: на карту отряда или на карту погоды.
void _checkCardRefs(PackRules rules, EffectKey effect, Map<String, EffectParam> params, String path, IssueSink sink) {
  for (final spec in effect.params) {
    final param = params[spec.name];
    final ids = switch (param) {
      CardRefParam(:final cardId) => [cardId],
      CardRefsParam(:final cardIds) => cardIds,
      _ => const <String>[],
    };
    for (final id in ids) {
      final at = '$path.${spec.name}';
      if (spec.type == ParamType.weatherCard) {
        final card = rules.specialCardsById[id];
        final ability = card == null ? null : rules.specialAbilitiesById[card.abilityId];
        if (ability?.effect != EffectKey.weather) {
          sink.add(at, 'unknown_reference', 'нет специальной карты погоды $id');
        }
      } else if (!rules.squadCardsById.containsKey(id)) {
        sink.add(at, 'unknown_reference', 'нет карты отряда $id');
      }
    }
  }
}

void _checkStrings(PackRules rules, Map<String, StringTable> strings, IssueSink sink) {
  final used = <String, String>{};
  void use(String path, String? key) {
    if (key != null) used.putIfAbsent(key, () => path);
  }

  void abilities(String table, List<Ability> items) {
    for (final (i, ability) in items.indexed) {
      use('\$.$table[$i].name_key', ability.nameKey);
      use('\$.$table[$i].description_key', ability.descriptionKey);
    }
  }

  for (final (i, zone) in rules.zones.indexed) {
    use('\$.zones[$i].name_key', zone.nameKey);
  }
  for (final (i, fraction) in rules.fractions.indexed) {
    use('\$.fractions[$i].name_key', fraction.nameKey);
  }
  abilities('fraction_abilities', rules.fractionAbilities);
  abilities('squad_abilities', rules.squadAbilities);
  abilities('special_abilities', rules.specialAbilities);
  abilities('leader_abilities', rules.leaderAbilities);
  for (final (i, card) in rules.squadCards.indexed) {
    use('\$.squad_cards[$i].name_key', card.nameKey);
    use('\$.squad_cards[$i].description_key', card.descriptionKey);
  }
  for (final (i, card) in rules.specialCards.indexed) {
    use('\$.special_cards[$i].name_key', card.nameKey);
    use('\$.special_cards[$i].description_key', card.descriptionKey);
  }
  for (final (i, card) in rules.leaderCards.indexed) {
    use('\$.leader_cards[$i].name_key', card.nameKey);
    use('\$.leader_cards[$i].description_key', card.descriptionKey);
  }

  for (final MapEntry(key: locale, value: table) in strings.entries) {
    for (final MapEntry(:key, value: path) in used.entries) {
      if (table[key] == null) sink.add(path, 'missing_string', 'нет текста $key на языке $locale');
    }
    for (final key in table.entries.keys) {
      if (!used.containsKey(key)) {
        sink.add('\$["$key"]', 'unused_string', 'текст не нужен ни одной записи', file: stringsFileName(locale));
      }
    }
  }
}
