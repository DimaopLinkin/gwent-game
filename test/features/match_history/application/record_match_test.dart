import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';

import '../../../support/fakes.dart';

void main() {
  test('партия записывается с идентификатором и временем окончания', () async {
    final repository = InMemoryMatchHistoryRepository();
    final clock = FakeClock(DateTime.utc(2026, 10, 11, 20));

    final record = await RecordMatch(repository, clock, SequentialIdGenerator())(
      mode: MatchMode.hotSeat,
      playerFactionId: 'skellige',
      opponentFactionId: 'nilfgaard',
      outcome: MatchOutcome.victory,
      roundsWon: 2,
      roundsLost: 1,
    );

    expect(record.id, 'id-1');
    expect(record.finishedAt, clock.current);
    expect(record.opponentName, isNull);
    expect(repository.records, [record]);
  });
}
