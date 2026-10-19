/// Тип параметра эффекта и его ограничения.
enum ParamType {
  /// Целое число не меньше 1.
  count,

  /// Один ряд: `melee`, `ranged` или `siege`.
  row,

  /// Непустой список разных рядов.
  rows,

  /// UUID карты отряда.
  squadCard,

  /// Непустой список разных UUID карт отрядов.
  squadCards,

  /// UUID специальной карты с эффектом погоды (`weather`).
  weatherCard,
}

/// Описание одного параметра эффекта: имя в JSON и тип.
final class ParamSpec {
  /// Создаёт описание параметра [name] типа [type].
  const ParamSpec(this.name, this.type);

  /// Имя параметра в `params` и `ability_params`.
  final String name;

  /// Тип параметра.
  final ParamType type;
}
