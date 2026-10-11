import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Почему закончилась партия.
enum MatchEndReason {
  /// У кого-то кончились кристаллы (раздел 7).
  crystals,

  /// Игрок сдался.
  resignation,
}

/// Итог партии.
final class MatchOutcome extends Value {
  const MatchOutcome({required this.winner, required this.reason});

  /// Победитель; `null` при ничьей.
  final Seat? winner;
  final MatchEndReason reason;

  @override
  List<Object?> get props => [winner, reason];
}
