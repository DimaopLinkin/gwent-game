import 'package:drift/drift.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';

/// История партий в базе Drift.
final class DriftMatchHistoryRepository implements MatchHistoryRepository {
  /// Создаёт репозиторий над [database].
  const DriftMatchHistoryRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<MatchRecord>> watchAll() {
    final query = _db.select(_db.matchRecords)
      ..orderBy([(row) => OrderingTerm.desc(row.finishedAt), (row) => OrderingTerm.asc(row.id)]);
    return query.watch().map((rows) => rows.map(_toRecord).toList());
  }

  @override
  Future<void> add(MatchRecord record) => _db
      .into(_db.matchRecords)
      .insert(
        MatchRecordsCompanion.insert(
          id: record.id,
          mode: record.mode,
          playerFactionId: record.playerFactionId,
          opponentFactionId: record.opponentFactionId,
          opponentName: Value(record.opponentName),
          outcome: record.outcome,
          roundsWon: record.roundsWon,
          roundsLost: record.roundsLost,
          finishedAt: record.finishedAt,
        ),
      );

  MatchRecord _toRecord(MatchRecordRow row) => MatchRecord(
    id: row.id,
    mode: row.mode,
    playerFactionId: row.playerFactionId,
    opponentFactionId: row.opponentFactionId,
    opponentName: row.opponentName,
    outcome: row.outcome,
    roundsWon: row.roundsWon,
    roundsLost: row.roundsLost,
    finishedAt: row.finishedAt,
  );
}
