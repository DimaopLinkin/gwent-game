import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/match_history/data/drift_match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';

import '../../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftMatchHistoryRepository repository;

  setUp(() {
    db = openTestDatabase();
    repository = DriftMatchHistoryRepository(db);
  });

  tearDown(() => db.close());

  MatchRecord record(String id, DateTime finishedAt, {String? opponentName}) => MatchRecord(
    id: id,
    mode: MatchMode.wifi,
    playerFactionId: 'skellige',
    opponentFactionId: 'monsters',
    opponentName: opponentName,
    outcome: MatchOutcome.draw,
    roundsWon: 1,
    roundsLost: 1,
    finishedAt: finishedAt,
  );

  test('партии читаются без изменений, последние первыми', () async {
    final first = record('a', DateTime.utc(2026, 10, 1, 18), opponentName: 'Цири');
    final second = record('b', DateTime.utc(2026, 10, 2, 18));

    await repository.add(first);
    await repository.add(second);

    expect(await repository.watchAll().first, [second, first]);
  });

  test('время окончания в другом часовом поясе сохраняется в UTC и сортируется по моменту', () async {
    // Момент 12:00 UTC в локальном поясе машины. Где пояс не UTC (например, 15:00 по Москве), без перевода в UTC
    // текст «15:00+03:00» встал бы позже «13:00Z».
    final moscow = record('msk', DateTime.parse('2026-10-11T15:00:00+03:00').toLocal());
    final utc = record('utc', DateTime.utc(2026, 10, 11, 13));

    await repository.add(moscow);
    await repository.add(utc);

    final records = await repository.watchAll().first;
    expect([for (final record in records) record.id], ['utc', 'msk']);
    expect(records.last.finishedAt, DateTime.utc(2026, 10, 11, 12));
  });

  test('режим и итог хранятся стабильными кодами', () async {
    const modes = {
      MatchMode.hotSeat: 'hot_seat',
      MatchMode.wifi: 'wifi',
      MatchMode.bluetooth: 'bluetooth',
      MatchMode.server: 'server',
      MatchMode.ai: 'ai',
    };
    const outcomes = {MatchOutcome.victory: 'victory', MatchOutcome.defeat: 'defeat', MatchOutcome.draw: 'draw'};
    expect(modes.keys, containsAll(MatchMode.values), reason: 'новому режиму нужен код');
    expect(outcomes.keys, containsAll(MatchOutcome.values), reason: 'новому итогу нужен код');

    var minute = 0;
    final written = [
      for (final mode in MatchMode.values)
        for (final outcome in MatchOutcome.values)
          MatchRecord(
            id: '${mode.name}-${outcome.name}',
            mode: mode,
            playerFactionId: 'skellige',
            opponentFactionId: 'monsters',
            opponentName: null,
            outcome: outcome,
            roundsWon: 0,
            roundsLost: 0,
            finishedAt: DateTime.utc(2026, 10, 11, 12, minute++),
          ),
    ];
    for (final record in written) {
      await repository.add(record);
    }

    final rows = await db.select(db.matchRecords).get();
    expect(
      {for (final row in rows) row.id: (row.mode, row.outcome)},
      {
        for (final record in written) record.id: (modes[record.mode], outcomes[record.outcome]),
      },
    );
    expect((await repository.watchAll().first).toSet(), written.toSet());
  });
}
