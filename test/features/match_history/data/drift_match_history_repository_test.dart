import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/match_history/data/drift_match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent_engine/gwent_engine.dart'
    show
        CardId,
        Deck,
        Faction,
        LeaderId,
        MatchEndReason,
        MatchPhase,
        Pass,
        Passed,
        PlayerView,
        RoundResult,
        RoundStarted,
        Seat,
        SideView;
import 'package:gwent_engine/gwent_engine.dart' as engine show MatchOutcome;
import 'package:gwent_net/gwent_net.dart' as net;

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

  JournalReplayLog journal({Seat perspective = Seat.one}) => JournalReplayLog(
    const net.MatchRecord(
      matchId: 'local-7',
      ruleset: net.Ruleset(id: 'pack', hash: 'abc', engineVersion: 1),
      seed: 7,
      one: Deck(leader: LeaderId('l1'), cards: [CardId('c1'), CardId('c2')]),
      two: Deck(leader: LeaderId('l2'), cards: [CardId('c3')]),
      moves: [net.RecordedMove(Seat.one, Pass())],
    ),
    perspective: perspective,
  );

  group('реплей', () {
    test('партия с реплеем читается с признаком, реплей находится по идентификатору', () async {
      final log = journal(perspective: Seat.two);
      await repository.add(record('a', DateTime.utc(2026, 10)), replay: log);
      await repository.add(record('b', DateTime.utc(2026, 10, 2)));

      final records = await repository.watchAll().first;
      expect({for (final record in records) record.id: record.hasReplay}, {'a': true, 'b': false});
      expect(await repository.findReplay('a'), log);
      expect(await repository.findReplay('b'), isNull);
      expect(await repository.findReplay('нет'), isNull);
      expect((await repository.findById('a'))?.hasReplay, isTrue);
      expect(await repository.findById('нет'), isNull);
    });

    test('кадры гостя сетевой партии читаются без изменений вместе с набором правил', () async {
      const ruleset = net.Ruleset(id: 'pack', hash: 'abc', engineVersion: 1);
      final view = PlayerView(
        viewer: Seat.two,
        phase: MatchPhase.finished,
        round: 2,
        me: _side(Seat.two),
        opponent: _side(Seat.one),
        weather: const [],
        history: const [
          RoundResult(round: 1, scores: {Seat.one: 3, Seat.two: 5}, winner: Seat.two),
        ],
        outcome: const engine.MatchOutcome(winner: Seat.two, reason: MatchEndReason.crystals),
      );
      final log = FramesReplayLog(
        [
          (view: view, events: const [RoundStarted(1, Seat.one), Passed(Seat.one, auto: false)]),
          (view: view, events: const []),
        ],
        ruleset: ruleset,
        perspective: Seat.two,
      );
      await repository.add(record('f', DateTime.utc(2026, 10, 3)), replay: log);

      expect(await repository.findReplay('f'), log);
      final row = await (db.select(db.matchReplays)..where((row) => row.recordId.equals('f'))).getSingle();
      expect((row.perspective, row.kind, row.formatVersion), ('two', 'frames', 1));
    });

    test('повреждённые кадры и чужая версия формата дают ReplayCorrupted', () async {
      await repository.add(record('f', DateTime.utc(2026, 10, 3)), replay: journal());
      Future<void> store(String payload, {int version = 1}) =>
          (db.update(db.matchReplays)..where((row) => row.recordId.equals('f'))).write(
            MatchReplaysCompanion(kind: const Value('frames'), formatVersion: Value(version), payload: Value(payload)),
          );

      await store('{"ruleset": {"id": "p", "hash": "h", "engine": 1}, "frames": []}');
      await expectLater(repository.findReplay('f'), throwsA(isA<ReplayCorrupted>()));
      await store('{"ruleset": {"id": "p", "hash": "h"}, "frames": [{}]}');
      await expectLater(repository.findReplay('f'), throwsA(isA<ReplayCorrupted>()));
      await store('{"frames": [{"view": 1}]}');
      await expectLater(repository.findReplay('f'), throwsA(isA<ReplayCorrupted>()));
      await store('{}', version: 9);
      await expectLater(repository.findReplay('f'), throwsA(isA<ReplayCorrupted>()));
    });

    test('партия и реплей пишутся вместе: сбой записи реплея не оставляет сводку', () async {
      await db
          .into(db.matchReplays)
          .insert(
            MatchReplaysCompanion.insert(
              recordId: 'b',
              perspective: 'one',
              kind: 'journal',
              formatVersion: 1,
              payload: '{}',
            ),
          );

      await expectLater(repository.add(record('b', DateTime.utc(2026, 10, 2)), replay: journal()), throwsA(anything));

      expect(await repository.watchAll().first, isEmpty);
    });

    test('повреждённая запись реплея даёт ReplayCorrupted', () async {
      await repository.add(record('a', DateTime.utc(2026, 10)), replay: journal());
      await (db.update(db.matchReplays)..where((row) => row.recordId.equals('a'))).write(
        const MatchReplaysCompanion(payload: Value('{"match": 1}')),
      );
      await expectLater(repository.findReplay('a'), throwsA(isA<ReplayCorrupted>()));

      await (db.update(db.matchReplays)..where((row) => row.recordId.equals('a'))).write(
        const MatchReplaysCompanion(payload: Value('не json')),
      );
      await expectLater(repository.findReplay('a'), throwsA(isA<ReplayCorrupted>()));
    });

    test('неизвестный вид записи и версия формата дают ReplayCorrupted', () async {
      await repository.add(record('a', DateTime.utc(2026, 10)), replay: journal());
      await (db.update(db.matchReplays)..where((row) => row.recordId.equals('a'))).write(
        const MatchReplaysCompanion(kind: Value('кадры')),
      );
      await expectLater(repository.findReplay('a'), throwsA(isA<ReplayCorrupted>()));

      await (db.update(db.matchReplays)..where((row) => row.recordId.equals('a'))).write(
        const MatchReplaysCompanion(kind: Value('journal'), formatVersion: Value(99)),
      );
      await expectLater(repository.findReplay('a'), throwsA(isA<ReplayCorrupted>()));
    });
  });
}

SideView _side(Seat seat) => SideView(
  seat: seat,
  leader: const LeaderId('leader'),
  faction: Faction.skellige,
  leaderAvailable: false,
  leaderUsed: false,
  leaderDisabled: false,
  crystals: 1,
  passed: true,
  handCount: 0,
  deckCount: 0,
  discard: const [],
  rows: const {},
  score: 0,
  redrawDone: true,
);
