import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' as history;
import 'package:gwent_engine/gwent_engine.dart';

/// Сценарий: записать законченную партию в историю глазами `MatchSession.perspective`.
final class RecordFinishedMatch {
  /// Создаёт сценарий.
  const RecordFinishedMatch(this._recordMatch);

  final RecordMatch _recordMatch;

  /// Записывает партию по итоговой проекции [finalView] любого здешнего места.
  ///
  /// Бросает [ArgumentError], если партия в [finalView] ещё не окончена.
  Future<history.MatchRecord> call(MatchSession session, PlayerView finalView) {
    final outcome = finalView.outcome;
    if (outcome == null) throw ArgumentError.value(finalView.phase, 'finalView', 'Партия ещё не окончена');
    final me = session.perspective;
    int won(Seat seat) => finalView.history.where((round) => round.winner == seat).length;
    return _recordMatch(
      mode: session.mode,
      playerFactionId: session.factionIds[me]!,
      opponentFactionId: session.factionIds[me.opponent]!,
      outcome: switch (outcome.winner) {
        null => history.MatchOutcome.draw,
        final winner when winner == me => history.MatchOutcome.victory,
        _ => history.MatchOutcome.defeat,
      },
      roundsWon: won(me),
      roundsLost: won(me.opponent),
    );
  }
}
