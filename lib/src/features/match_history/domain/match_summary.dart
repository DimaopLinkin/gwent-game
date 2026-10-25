import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent_engine/gwent_engine.dart' show PlayerView, Seat;
import 'package:meta/meta.dart';

/// Итог законченной партии для игрока на месте [MatchSummary.me]: то, что попадает в историю.
@immutable
final class MatchSummary {
  /// Подводит итог партии по последней проекции [finalView] глазами места [me].
  ///
  /// Бросает [ArgumentError], если партия в [finalView] ещё не окончена.
  factory MatchSummary.of(PlayerView finalView, Seat me) {
    final outcome = finalView.outcome;
    if (outcome == null) throw ArgumentError.value(finalView.phase, 'finalView', 'Партия ещё не окончена');
    int won(Seat seat) => finalView.history.where((round) => round.winner == seat).length;
    return MatchSummary._(
      outcome: switch (outcome.winner) {
        null => MatchOutcome.draw,
        final winner when winner == me => MatchOutcome.victory,
        _ => MatchOutcome.defeat,
      },
      roundsWon: won(me),
      roundsLost: won(me.opponent),
    );
  }

  const MatchSummary._({required this.outcome, required this.roundsWon, required this.roundsLost});

  /// Итог для игрока.
  final MatchOutcome outcome;

  /// Раунды, выигранные игроком.
  final int roundsWon;

  /// Раунды, выигранные соперником.
  final int roundsLost;
}
