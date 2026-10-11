import 'package:drift/drift.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';

/// История партий в базе Drift.
///
/// Режим и итог хранятся стабильными строковыми кодами, а не именами значений enum: переименование значения
/// в домене не трогает данные. Новый код добавляется в оба `switch`, старые коды не меняются никогда.
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
          mode: _modeCode(record.mode),
          playerFactionId: record.playerFactionId,
          opponentFactionId: record.opponentFactionId,
          opponentName: Value(record.opponentName),
          outcome: _outcomeCode(record.outcome),
          roundsWon: record.roundsWon,
          roundsLost: record.roundsLost,
          // Сортировка идёт по тексту ISO-8601 и верна, только если все моменты записаны в UTC.
          finishedAt: record.finishedAt.toUtc(),
        ),
      );

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
