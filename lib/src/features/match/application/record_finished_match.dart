import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' as history;
import 'package:gwent/src/features/match_history/domain/match_summary.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Сценарий: записать законченную партию в историю глазами `MatchSession.perspective`.
final class RecordFinishedMatch {
  /// Создаёт сценарий.
  const RecordFinishedMatch(this._recordMatch);

  final RecordMatch _recordMatch;

  /// Записывает партию по итоговой проекции [finalView] любого здешнего места; вместе с ней сохраняется реплей,
  /// если сессия записывалась (`MatchSession.recorder`).
  ///
  /// Бросает [ArgumentError], если партия в [finalView] ещё не окончена.
  Future<history.MatchRecord> call(MatchSession session, PlayerView finalView) {
    final summary = MatchSummary.of(finalView, session.perspective);
    return _recordMatch(
      mode: session.mode,
      playerFactionId: session.factionIds[session.perspective]!,
      opponentFactionId: session.factionIds[session.perspective.opponent]!,
      opponentName: session.opponentName,
      outcome: summary.outcome,
      roundsWon: summary.roundsWon,
      roundsLost: summary.roundsLost,
      replay: session.recorder?.log,
    );
  }
}
