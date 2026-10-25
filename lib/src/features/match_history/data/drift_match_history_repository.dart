import 'package:drift/drift.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/match_history/data/replay_log_codec.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';

/// История партий в базе Drift.
///
/// Режим и итог хранятся стабильными строковыми кодами, а не именами значений enum: переименование значения
/// в домене не трогает данные. Новый код добавляется в оба `switch`, старые коды не меняются никогда.
final class DriftMatchHistoryRepository implements MatchHistoryRepository {
  /// Создаёт репозиторий над [database].
  const DriftMatchHistoryRepository(this._db, {ReplayLogCodec codec = const ReplayLogCodec()}) : _codec = codec;

  final AppDatabase _db;
  final ReplayLogCodec _codec;

  @override
  Stream<List<MatchRecord>> watchAll() {
    final query = _db.select(_db.matchRecords)
      ..orderBy([(row) => OrderingTerm.desc(row.finishedAt), (row) => OrderingTerm.asc(row.id)]);
    return query.watch().map((rows) => rows.map(_toRecord).toList());
  }

  @override
  Future<MatchRecord?> findById(String id) async {
    final row = await (_db.select(_db.matchRecords)..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  @override
  Future<void> add(MatchRecord record, {ReplayLog? replay}) => _db.transaction(() async {
    await _db
        .into(_db.matchRecords)
        .insert(
          MatchRecordsCompanion.insert(
            id: record.id,
            mode: _modeCode(record.mode),
            playerFactionId: record.playerFactionId,
            opponentFactionId: record.opponentFactionId,
            opponentName: Value(record.opponentName),
            outcome: _outcomeCode(record.outcome),
            roundsWon: record.roundsWon,
            roundsLost: record.roundsLost,
            // Сортировка идёт по тексту ISO-8601 и верна, только если все моменты записаны в UTC.
            finishedAt: record.finishedAt.toUtc(),
            hasReplay: Value(replay != null),
          ),
        );
    if (replay != null) {
      final encoded = _codec.encode(replay);
      await _db
          .into(_db.matchReplays)
          .insert(
            MatchReplaysCompanion.insert(
              recordId: record.id,
              perspective: encoded.perspective,
              kind: encoded.kind,
              formatVersion: encoded.formatVersion,
              payload: encoded.payload,
            ),
          );
    }
  });

  @override
  Future<ReplayLog?> findReplay(String recordId) async {
    final row = await (_db.select(_db.matchReplays)..where((row) => row.recordId.equals(recordId))).getSingleOrNull();
    if (row == null) return null;
    return _codec.decode((
      perspective: row.perspective,
      kind: row.kind,
      formatVersion: row.formatVersion,
      payload: row.payload,
    ));
  }

  MatchRecord _toRecord(MatchRecordRow row) => MatchRecord(
    id: row.id,
    mode: _modeFromCode(row.mode),
    playerFactionId: row.playerFactionId,
    opponentFactionId: row.opponentFactionId,
    opponentName: row.opponentName,
    outcome: _outcomeFromCode(row.outcome),
    roundsWon: row.roundsWon,
    roundsLost: row.roundsLost,
    finishedAt: row.finishedAt,
    hasReplay: row.hasReplay,
  );

  static String _modeCode(MatchMode mode) => switch (mode) {
    MatchMode.hotSeat => 'hot_seat',
    MatchMode.wifi => 'wifi',
    MatchMode.bluetooth => 'bluetooth',
    MatchMode.server => 'server',
    MatchMode.ai => 'ai',
  };

  static MatchMode _modeFromCode(String code) => switch (code) {
    'hot_seat' => MatchMode.hotSeat,
    'wifi' => MatchMode.wifi,
    'bluetooth' => MatchMode.bluetooth,
    'server' => MatchMode.server,
    'ai' => MatchMode.ai,
    _ => throw FormatException('Неизвестный режим партии в базе', code),
  };

  static String _outcomeCode(MatchOutcome outcome) => switch (outcome) {
    MatchOutcome.victory => 'victory',
    MatchOutcome.defeat => 'defeat',
    MatchOutcome.draw => 'draw',
  };

  static MatchOutcome _outcomeFromCode(String code) => switch (code) {
    'victory' => MatchOutcome.victory,
    'defeat' => MatchOutcome.defeat,
    'draw' => MatchOutcome.draw,
    _ => throw FormatException('Неизвестный итог партии в базе', code),
  };
}
