/// Фракция (`fractions`).
final class Fraction {
  /// Создаёт фракцию.
  const Fraction({
    required this.id,
    required this.key,
    required this.isDeck,
    required this.abilityId,
    required this.nameKey,
  });

  /// UUID фракции.
  final String id;

  /// Машинный ключ латиницей, например `skellige`.
  final String key;

  /// Можно ли собрать колоду этой фракции. Карты фракций без колоды нейтральные и доступны всем.
  final bool isDeck;

  /// UUID перка фракции (`fraction_abilities`) или `null`.
  final String? abilityId;

  /// Ключ строки с названием.
  final String nameKey;
}
