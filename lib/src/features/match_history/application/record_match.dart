import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/core/domain/id_generator.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';

/// Сценарий: записать завершённую партию в историю.
final class RecordMatch {
  /// Создаёт сценарий.
  const RecordMatch(this._repository, this._clock, this._ids);

  final MatchHistoryRepository _repository;
  final Clock _clock;
  final IdGenerator _ids;

  /// Записывает партию с моментом окончания «сейчас» и возвращает запись; с [replay] сохраняется и реплей партии.
  Future<MatchRecord> call({
    required MatchMode mode,
    required String playerFactionId,
    required String opponentFactionId,
    String? opponentName,
    required MatchOutcome outcome,
    required int roundsWon,
    required int roundsLost,
    ReplayLog? replay,
  }) async {
    final record = MatchRecord(
      id: _ids.next(),
      mode: mode,
      playerFactionId: playerFactionId,
      opponentFactionId: opponentFactionId,
      opponentName: opponentName,
      outcome: outcome,
      roundsWon: roundsWon,
      roundsLost: roundsLost,
      finishedAt: _clock.now(),
      hasReplay: replay != null,
    );
    await _repository.add(record, replay: replay);
    return record;
  }
}
