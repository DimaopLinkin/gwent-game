import 'package:gwent_engine/gwent_engine.dart';

/// Что подсвечивает слой подсказок: место на поле по смыслу, без координат (их находит экран).
sealed class HintTarget extends Value {
  const HintTarget();
}

/// Камни жизни обоих игроков.
final class GemsHint extends HintTarget {
  /// Создаёт цель.
  const GemsHint();

  @override
  List<Object?> get props => const [];
}

/// Рука игрока.
final class HandHint extends HintTarget {
  /// Создаёт цель.
  const HandHint();

  @override
  List<Object?> get props => const [];
}

/// Колода и сброс игрока.
final class PilesHint extends HintTarget {
  /// Создаёт цель.
  const PilesHint();

  @override
  List<Object?> get props => const [];
}

/// Карта в руке игрока: первая с этим [cardId] по порядку руки.
final class HandCardHint extends HintTarget {
  /// Создаёт цель.
  const HandCardHint(this.cardId);

  /// UUID карты пакета контента.
  final String cardId;

  @override
  List<Object?> get props => [cardId];
}

/// Ряд [row] игрока ([mine]) или соперника.
final class RowHint extends HintTarget {
  /// Создаёт цель.
  const RowHint(this.row, {required this.mine});

  /// Ряд.
  final Row row;

  /// Свой ряд.
  final bool mine;

  @override
  List<Object?> get props => [row, mine];
}

/// Число силы ряда [row] игрока ([mine]) или соперника.
final class RowScoreHint extends HintTarget {
  /// Создаёт цель.
  const RowScoreHint(this.row, {required this.mine});

  /// Ряд.
  final Row row;

  /// Свой ряд.
  final bool mine;

  @override
  List<Object?> get props => [row, mine];
}

/// Центральная полоса с погодой.
final class StripHint extends HintTarget {
  /// Создаёт цель.
  const StripHint();

  @override
  List<Object?> get props => const [];
}

/// Общий счёт игрока ([mine]) или соперника.
final class ScoreHint extends HintTarget {
  /// Создаёт цель.
  const ScoreHint({required this.mine});

  /// Свой счёт.
  final bool mine;

  @override
  List<Object?> get props => [mine];
}

/// Кнопка «Пас».
final class PassHint extends HintTarget {
  /// Создаёт цель.
  const PassHint();

  @override
  List<Object?> get props => const [];
}

/// Карта лидера игрока.
final class LeaderHint extends HintTarget {
  /// Создаёт цель.
  const LeaderHint();

  @override
  List<Object?> get props => const [];
}
