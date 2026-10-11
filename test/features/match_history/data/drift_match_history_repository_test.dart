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
}
