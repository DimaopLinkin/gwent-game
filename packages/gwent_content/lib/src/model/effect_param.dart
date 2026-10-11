import 'package:gwent_content/src/model/combat_row.dart';
import 'package:gwent_content/src/model/param_type.dart';

/// Значение параметра эффекта после проверки типа.
sealed class EffectParam {
  const EffectParam();
}

/// Целое число не меньше 1 ([ParamType.count]).
final class CountParam extends EffectParam {
  /// Создаёт параметр со значением [value].
  const CountParam(this.value);

  /// Значение.
  final int value;
}

/// Один ряд ([ParamType.row]).
final class RowParam extends EffectParam {
  /// Создаёт параметр со значением [value].
  const RowParam(this.value);

  /// Ряд.
  final CombatRow value;
}

/// Список разных рядов ([ParamType.rows]).
final class RowsParam extends EffectParam {
  /// Создаёт параметр со значением [value].
  const RowsParam(this.value);

  /// Ряды в порядке из пакета.
  final List<CombatRow> value;
}

/// UUID одной карты ([ParamType.squadCard], [ParamType.weatherCard]).
final class CardRefParam extends EffectParam {
  /// Создаёт параметр со ссылкой [cardId].
  const CardRefParam(this.cardId);

  /// UUID карты.
  final String cardId;
}

/// UUID нескольких разных карт ([ParamType.squadCards]).
final class CardRefsParam extends EffectParam {
  /// Создаёт параметр со ссылками [cardIds].
  const CardRefsParam(this.cardIds);

  /// UUID карт в порядке из пакета.
  final List<String> cardIds;
}
