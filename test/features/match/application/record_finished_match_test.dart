import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' as history;
import 'package:gwent_engine/gwent_engine.dart';

import '../../../support/fakes.dart';
import '../../../support/match_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late InMemoryMatchHistoryRepository repository;
  late RecordFinishedMatch record;

  setUpAll(() async => content = await loadBaseContent());

  setUp(() {
    repository = InMemoryMatchHistoryRepository();
    record = RecordFinishedMatch(
      RecordMatch(repository, FakeClock(DateTime.utc(2026, 10, 12, 9)), SequentialIdGenerator()),
    );
  });

  MatchSession session(history.MatchMode mode, Set<Seat> localSeats, {String? opponentName}) => MatchSession(
    mode: mode,
    table: _Table(localSeats),
    content: content,
    factionIds: const {Seat.one: 'skellige', Seat.two: 'monsters'},
    opponentName: opponentName,
  );

  test('победа против бота: режим ai, фракции и раунды глазами первого места', () async {
    final saved = await record(
      session(history.MatchMode.ai, {Seat.one}),
      _finalView(winner: Seat.one, rounds: [Seat.two, Seat.one, Seat.one]),
    );
    expect(repository.records, [saved]);
    expect(saved.mode, history.MatchMode.ai);
    expect(saved.playerFactionId, 'skellige');
    expect(saved.opponentFactionId, 'monsters');
    expect(saved.outcome, history.MatchOutcome.victory);
    expect((saved.roundsWon, saved.roundsLost), (2, 1));
    expect(saved.finishedAt, DateTime.utc(2026, 10, 12, 9));
  });

  test('hot-seat записывается глазами первого игрока при проекции второго', () async {
    final saved = await record(
      session(history.MatchMode.hotSeat, Seat.values.toSet()),
      _finalView(winner: Seat.two, rounds: [Seat.two, Seat.two], viewer: Seat.two),
    );
    expect(saved.mode, history.MatchMode.hotSeat);
    expect(saved.outcome, history.MatchOutcome.defeat);
    expect((saved.roundsWon, saved.roundsLost), (0, 2));
  });

  test('сетевая партия: в истории остаётся имя соперника в сети', () async {
    final saved = await record(
      session(history.MatchMode.wifi, {Seat.two}, opponentName: 'Вереск'),
      _finalView(winner: Seat.two, rounds: [Seat.two, Seat.two], viewer: Seat.two),
    );
    expect(saved.mode, history.MatchMode.wifi);
    expect(saved.opponentName, 'Вереск');
    expect(saved.outcome, history.MatchOutcome.victory);
  });

  test('ничья: раунды вничью не идут в счёт', () async {
    final saved = await record(
      session(history.MatchMode.ai, {Seat.one}),
      _finalView(winner: null, rounds: [null, null]),
    );
    expect(saved.outcome, history.MatchOutcome.draw);
    expect((saved.roundsWon, saved.roundsLost), (0, 0));
  });

  test('неоконченную партию записать нельзя', () {
    final view = _finalView(winner: Seat.one, rounds: const [], finished: false);
    expect(() => record(session(history.MatchMode.ai, {Seat.one}), view), throwsArgumentError);
  });
}

PlayerView _finalView({
  required Seat? winner,
  required List<Seat?> rounds,
  Seat viewer = Seat.one,
  bool finished = true,
}) {
  SideView side(Seat seat) => SideView(
    seat: seat,
    leader: const LeaderId('leader'),
    faction: Faction.skellige,
    leaderAvailable: false,
    leaderUsed: false,
    leaderDisabled: false,
    crystals: 0,
    passed: true,
    handCount: 0,
    deckCount: 0,
    discard: const [],
    rows: const {},
    score: 0,
    redrawDone: true,
  );
  return PlayerView(
    viewer: viewer,
    phase: finished ? MatchPhase.finished : MatchPhase.playing,
    round: rounds.length,
    me: side(viewer),
    opponent: side(viewer.opponent),
    weather: const [],
    history: [
      for (final (index, roundWinner) in rounds.indexed)
        RoundResult(round: index + 1, scores: const {Seat.one: 0, Seat.two: 0}, winner: roundWinner),
    ],
    outcome: finished ? MatchOutcome(winner: winner, reason: MatchEndReason.crystals) : null,
  );
}

/// Стол, у которого важны только здешние места.
final class _Table implements MatchTable {
  _Table(this.localSeats);

  @override
  final Set<Seat> localSeats;

  @override
  Stream<TableUpdate> get updates => const Stream.empty();

  @override
  void submit(Seat seat, Intent intent) {}

  @override
  Future<void> close() async {}
}
