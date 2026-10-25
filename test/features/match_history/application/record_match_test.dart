import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent_engine/gwent_engine.dart' show CardId, Deck, LeaderId, Seat;
import 'package:gwent_net/gwent_net.dart' as net;

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

  test('с реплеем запись помечена и реплей сохранён вместе с ней', () async {
    final repository = InMemoryMatchHistoryRepository();
    const deck = Deck(leader: LeaderId('l'), cards: [CardId('c')]);
    const replay = JournalReplayLog(
      net.MatchRecord(
        matchId: 'm',
        ruleset: net.Ruleset(id: 'pack', hash: 'h', engineVersion: 1),
        seed: 1,
        one: deck,
        two: deck,
      ),
      perspective: Seat.two,
    );

    final record = await RecordMatch(repository, FakeClock(DateTime.utc(2026, 10, 11, 20)), SequentialIdGenerator())(
      mode: MatchMode.wifi,
      playerFactionId: 'skellige',
      opponentFactionId: 'nilfgaard',
      outcome: MatchOutcome.defeat,
      roundsWon: 0,
      roundsLost: 2,
      replay: replay,
    );

    expect(record.hasReplay, isTrue);
    expect(repository.records, [record]);
    expect(repository.replays, {record.id: replay});
  });
}
