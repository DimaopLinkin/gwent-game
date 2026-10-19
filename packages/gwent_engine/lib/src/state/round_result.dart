import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Итог раунда для истории партии (раздел 5.1).
final class RoundResult extends Value {
  const RoundResult({required this.round, required this.scores, required this.winner});

  final int round;
  final Map<Seat, int> scores;

  /// Победитель раунда; `null` при ничьей, в которой оба потеряли кристалл.
  final Seat? winner;

  @override
  List<Object?> get props => [round, scores, winner];
}
