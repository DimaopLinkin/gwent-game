/// Числовые параметры партии и колоды (`game_rules`). Значения взяты из `docs/hand/main.md`.
final class GameRules {
  /// Создаёт параметры партии.
  const GameRules({
    required this.crystals,
    required this.startingHandSize,
    required this.maxRedraws,
    required this.minSquadCards,
    required this.maxSpecialCards,
  });

  /// Кристаллы (жизни) каждого игрока в начале партии (раздел 1).
  final int crystals;

  /// Сколько карт игрок берёт при раздаче (раздел 3, шаг 4).
  final int startingHandSize;

  /// Сколько карт можно заменить при пересдаче (раздел 3, шаг 5).
  final int maxRedraws;

  /// Минимум карт отрядов в колоде, герои считаются (раздел 2.1).
  final int minSquadCards;

  /// Максимум специальных карт в колоде (раздел 2.1).
  final int maxSpecialCards;
}
