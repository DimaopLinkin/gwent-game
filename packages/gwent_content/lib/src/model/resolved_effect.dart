import 'package:gwent_content/src/model/combat_row.dart';
import 'package:gwent_content/src/model/effect_key.dart';
import 'package:gwent_content/src/model/effect_param.dart';

/// Эффект способности карты с проверенными параметрами: `params` способности вместе с `ability_params` карты.
///
/// Получается из проверенного пакета через `PackRules.effectOf…`; поэтому типизированные геттеры не возвращают
/// `null`, а при обращении к параметру, которого у эффекта нет, бросают [StateError] (ошибка программиста).
final class ResolvedEffect {
  /// Создаёт эффект [effect] с параметрами [params].
  const ResolvedEffect(this.effect, this.params);

  /// Ключ эффекта.
  final EffectKey effect;

  /// Параметры по имени.
  final Map<String, EffectParam> params;

  /// Параметр-число [name].
  int count(String name) => switch (_param(name)) {
    CountParam(:final value) => value,
    _ => throw StateError('параметр $name эффекта ${effect.key} не число'),
  };

  /// Параметр-ряд [name].
  CombatRow row(String name) => switch (_param(name)) {
    RowParam(:final value) => value,
    _ => throw StateError('параметр $name эффекта ${effect.key} не ряд'),
  };

  /// Параметр-список рядов [name].
  List<CombatRow> rows(String name) => switch (_param(name)) {
    RowsParam(:final value) => value,
    _ => throw StateError('параметр $name эффекта ${effect.key} не список рядов'),
  };

  /// Параметр-ссылка на карту [name].
  String cardId(String name) => switch (_param(name)) {
    CardRefParam(:final cardId) => cardId,
    _ => throw StateError('параметр $name эффекта ${effect.key} не ссылка на карту'),
  };

  /// Параметр-список ссылок на карты [name].
  List<String> cardIds(String name) => switch (_param(name)) {
    CardRefsParam(:final cardIds) => cardIds,
    _ => throw StateError('параметр $name эффекта ${effect.key} не список ссылок на карты'),
  };

  EffectParam _param(String name) => params[name] ?? (throw StateError('у эффекта ${effect.key} нет параметра $name'));
}
