import 'package:gwent_content/src/json/uuid.dart';
import 'package:gwent_content/src/model/ability.dart';
import 'package:gwent_content/src/model/combat_row.dart';
import 'package:gwent_content/src/model/effect_param.dart';
import 'package:gwent_content/src/model/param_type.dart';
import 'package:gwent_content/src/model/raw_params.dart';
import 'package:gwent_content/src/model/resolved_effect.dart';

/// Получает сообщение о проблеме параметров: JSON-путь, машинный код и описание.
typedef ParamIssueSink = void Function(String path, String code, String message);

/// Складывает `params` способности [ability] и `ability_params` карты [cardParams] и проверяет их по описанию
/// эффекта: каждый параметр есть ровно в одном из двух мест, лишних нет, типы верны.
///
/// Существование карт по ссылкам здесь не проверяется: это делает проверка ссылок, у которой есть таблицы.
/// Возвращает `null`, если нашлась хотя бы одна проблема; проблемы уходят в [onIssue] с путями от [path].
ResolvedEffect? resolveEffect(
  Ability ability,
  RawParams cardParams, {
  required String path,
  required ParamIssueSink onIssue,
}) {
  var ok = true;
  void issue(String at, String code, String message) {
    ok = false;
    onIssue(at, code, message);
  }

  final merged = <String, Object>{...ability.params};
  for (final MapEntry(:key, :value) in cardParams.entries) {
    if (merged.containsKey(key)) {
      issue('$path.ability_params.$key', 'param_conflict', 'параметр $key задан и у способности ${ability.id}');
    }
    merged[key] = value;
  }

  final specs = {for (final spec in ability.effect.params) spec.name: spec};
  for (final name in merged.keys) {
    if (!specs.containsKey(name)) {
      issue('$path.$name', 'unknown_param', 'у эффекта ${ability.effect.key} нет параметра $name');
    }
  }

  final params = <String, EffectParam>{};
  for (final spec in ability.effect.params) {
    final value = merged[spec.name];
    final at = '$path.${spec.name}';
    if (value == null) {
      issue(at, 'missing_param', 'эффекту ${ability.effect.key} нужен параметр ${spec.name}');
      continue;
    }
    final param = _decode(spec.type, value);
    if (param == null) {
      issue(at, 'invalid_param', 'параметр ${spec.name} должен быть ${_describe(spec.type)}');
    } else {
      params[spec.name] = param;
    }
  }
  return ok ? ResolvedEffect(ability.effect, params) : null;
}

EffectParam? _decode(ParamType type, Object value) {
  switch (type) {
    case ParamType.count:
      return value is int && value >= 1 ? CountParam(value) : null;
    case ParamType.row:
      final row = value is String ? CombatRow.fromKey(value) : null;
      return row == null ? null : RowParam(row);
    case ParamType.rows:
      final keys = _distinctStrings(value);
      if (keys == null) return null;
      final rows = keys.map(CombatRow.fromKey).toList();
      return rows.contains(null) ? null : RowsParam(rows.nonNulls.toList());
    case ParamType.squadCard:
    case ParamType.weatherCard:
      return value is String && isCanonicalUuid(value) ? CardRefParam(value) : null;
    case ParamType.squadCards:
      final ids = _distinctStrings(value);
      return ids == null || !ids.every(isCanonicalUuid) ? null : CardRefsParam(ids);
  }
}

/// Непустой список разных строк или `null`.
List<String>? _distinctStrings(Object value) {
  if (value is! List<String> || value.isEmpty || value.toSet().length != value.length) return null;
  return List.unmodifiable(value);
}

String _describe(ParamType type) => switch (type) {
  ParamType.count => 'целым числом не меньше 1',
  ParamType.row => 'рядом: melee, ranged или siege',
  ParamType.rows => 'непустым списком разных рядов',
  ParamType.squadCard => 'UUID карты отряда',
  ParamType.weatherCard => 'UUID карты погоды',
  ParamType.squadCards => 'непустым списком разных UUID карт отрядов',
};
