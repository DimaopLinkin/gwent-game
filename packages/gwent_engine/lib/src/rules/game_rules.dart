import 'package:gwent_engine/src/core/value.dart';

/// Числовые параметры партии и колоды. Значения по умолчанию взяты из правил (`docs/hand/main.md`).
///
/// Позже их будет задавать таблица `game_rules` пакета контента; тесты подставляют свои значения,
/// чтобы играть маленькими колодами.
final class GameRules extends Value {
  const GameRules({
    this.startingHand = 10,
    this.redrawLimit = 2,
    this.crystals = 2,
    this.minUnitCards = 22,
    this.maxSpecialCards = 10,
  });

  /// Сколько карт игрок берёт при раздаче (раздел 3, шаг 4).
  final int startingHand;

  /// Сколько карт можно заменить при пересдаче (раздел 3, шаг 5).
  final int redrawLimit;

  /// Кристаллы (жизни) в начале партии.
  final int crystals;

  /// Минимум карт отрядов в колоде (раздел 2.1).
  final int minUnitCards;

  /// Максимум специальных карт в колоде (раздел 2.1).
  final int maxSpecialCards;

  @override
  List<Object?> get props => [startingHand, redrawLimit, crystals, minUnitCards, maxSpecialCards];
}
