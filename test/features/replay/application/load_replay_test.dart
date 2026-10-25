import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent/src/features/replay/application/load_replay.dart';
import 'package:gwent_content/gwent_content.dart' show InMemoryContentSource;
import 'package:gwent_engine/gwent_engine.dart' hide Deck, MatchOutcome;
import 'package:gwent_net/gwent_net.dart' as net;

import '../../../support/fakes.dart';
import '../../../support/replay_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryMatchHistoryRepository history;
  late LoadReplay loadReplay;
  late MatchRecord played;
  late LoadGameContent loader;

  setUpAll(() async {
    final match = await playRecordedMatch();
    history = match.history;
    played = match.record;
    loader = match.loader;
  });

  setUp(() => loadReplay = LoadReplay(history, loader));

  test('сыгранная партия загружается, шкала доходит до того же итога и счёта', () async {
    final result = await loadReplay(played.id);

    final data = (result as ReplayLoaded).data;
    expect(data.record, played);
    expect(data.timeline.matches(played), isTrue);
    expect(data.timeline.seats, Seat.values.toSet());
    expect(data.timeline.perspective, Seat.one);
    final journal = (history.replays[played.id]! as JournalReplayLog).journal;
    expect(data.timeline.frames, hasLength(journal.moves.length + 1));
  });

  test('шаги показа: первый шаг в ходе партии, последний в конце, события не теряются', () async {
    final data = ((await loadReplay(played.id)) as ReplayLoaded).data;

    for (final seat in Seat.values) {
      final steps = data.timeline.stepsFor(seat);
      expect(steps.first.view.phase, MatchPhase.playing);
      expect(steps.last.view.phase, MatchPhase.finished);
      expect(steps.last.view.outcome, isNotNull);
      // Кадры идут по возрастанию, а выбор движка и пересдача в шаги не попадают.
      expect([for (final step in steps) step.frame], orderedEquals([for (final step in steps) step.frame]..sort()));
      expect(steps.every((step) => step.view.choice == null && step.view.opponentChoosing == null), isTrue);
      // События пропущенных кадров доходят до следующего шага: подряд идущие шаги вместе дают все события зрителя.
      final shown = steps.expand((step) => step.events).toList();
      final all = data.timeline.frames.expand((frame) => frame.events[seat]!).toList();
      expect(shown, all);
      // Поле перед ходом, которым кончился раунд, есть ровно у шагов с концом раунда.
      for (final step in steps) {
        expect(step.closing != null, step.events.any((event) => event is RoundEnded));
      }
    }
  });

  test('чужой набор карт: ходы всё ещё принимаются, итог тот же, реплей открывается', () async {
    // Записанный хеш набора не совпадает с текущим, но партия проигрывается до того же итога.
    final repository = _TamperedHistory(history, hash: 'старый-набор');
    final result = await LoadReplay(repository, loader)(played.id);

    expect(result, isA<ReplayLoaded>());
  });

  test('итог не сходится со сводкой: реплей недоступен, причина — изменение набора, если хеш другой', () async {
    final tampered = _TamperedHistory(history, hash: 'старый-набор', roundsWon: played.roundsWon + 1);
    expect(
      await LoadReplay(tampered, loader)(played.id),
      isA<ReplayUnavailable>().having((result) => result.reason, 'reason', ReplayUnavailableReason.contentChanged),
    );

    final sameRules = _TamperedHistory(history, roundsWon: played.roundsWon + 1);
    expect(
      await LoadReplay(sameRules, loader)(played.id),
      isA<ReplayUnavailable>().having((result) => result.reason, 'reason', ReplayUnavailableReason.corrupted),
    );
  });

  test('ход, который движок не принимает, делает реплей недоступным', () async {
    final repository = _TamperedHistory(history, extraMove: const net.RecordedMove(Seat.one, FinishRedraw()));

    expect(
      await LoadReplay(repository, loader)(played.id),
      isA<ReplayUnavailable>().having((result) => result.reason, 'reason', ReplayUnavailableReason.corrupted),
    );
  });

  group('кадры гостя сетевой партии', () {
    late net.Ruleset ruleset;
    late List<net.ViewFrame> frames;

    setUp(() async {
      final data = ((await loadReplay(played.id)) as ReplayLoaded).data;
      ruleset = (history.replays[played.id]! as JournalReplayLog).journal.ruleset;
      frames = [
        for (final frame in data.timeline.frames) (view: frame.views[Seat.one]!, events: frame.events[Seat.one]!),
      ];
    });

    Future<LoadReplayResult> loadFrames(List<net.ViewFrame> frames, net.Ruleset ruleset) async {
      final repository = InMemoryMatchHistoryRepository();
      await repository.add(
        played,
        replay: FramesReplayLog(frames, ruleset: ruleset, perspective: Seat.one),
      );
      return LoadReplay(repository, loader)(played.id);
    }

    test('реплей открывается глазами одного места и доходит до того же итога', () async {
      final data = ((await loadFrames(frames, ruleset)) as ReplayLoaded).data;

      expect(data.timeline.seats, {Seat.one});
      expect(data.timeline.matches(played), isTrue);
      final steps = data.timeline.stepsFor(Seat.one);
      expect(steps.first.view.phase, MatchPhase.playing);
      expect(steps.last.view.outcome, isNotNull);
    });

    test('набор карт или движок другой: реплей недоступен из-за изменения набора', () async {
      final other = net.Ruleset(id: ruleset.id, hash: 'старый-набор', engineVersion: ruleset.engineVersion);
      expect(
        await loadFrames(frames, other),
        isA<ReplayUnavailable>().having((result) => result.reason, 'reason', ReplayUnavailableReason.contentChanged),
      );
    });

    test('кадры оборваны до конца партии: реплей не сходится со сводкой и недоступен', () async {
      expect(
        await loadFrames(frames.sublist(0, frames.length - 2), ruleset),
        isA<ReplayUnavailable>().having((result) => result.reason, 'reason', ReplayUnavailableReason.corrupted),
      );
    });
  });

  test('нет партии, нет реплея у старой партии, повреждённая запись', () async {
    expect(await loadReplay('нет такой'), isA<ReplayMissing>());

    final old = MatchRecord(
      id: 'old',
      mode: MatchMode.ai,
      playerFactionId: 'a',
      opponentFactionId: 'b',
      opponentName: null,
      outcome: MatchOutcome.victory,
      roundsWon: 2,
      roundsLost: 0,
      finishedAt: DateTime.utc(2026, 10),
    );
    await history.add(old);
    expect(await loadReplay('old'), isA<ReplayMissing>());

    final corrupted = _TamperedHistory(history, corrupted: true);
    expect(
      await LoadReplay(corrupted, loader)(played.id),
      isA<ReplayUnavailable>().having((result) => result.reason, 'reason', ReplayUnavailableReason.corrupted),
    );
  });

  test('набор карт не прошёл проверку: реплей не строится', () async {
    final result = await LoadReplay(history, LoadGameContent(InMemoryContentSource(const {})))(played.id);

    expect(result, isA<ReplayContentUnavailable>());
  });
}

/// История, которая отдаёт испорченную копию записи: другой хеш набора, другой счёт, лишний ход или мусор.
final class _TamperedHistory implements MatchHistoryRepository {
  _TamperedHistory(this._inner, {this.hash, this.roundsWon, this.extraMove, this.corrupted = false});

  final InMemoryMatchHistoryRepository _inner;
  final String? hash;
  final int? roundsWon;
  final net.RecordedMove? extraMove;
  final bool corrupted;

  @override
  Stream<List<MatchRecord>> watchAll() => _inner.watchAll();

  @override
  Future<void> add(MatchRecord record, {ReplayLog? replay}) => _inner.add(record, replay: replay);

  @override
  Future<MatchRecord?> findById(String id) async {
    final record = await _inner.findById(id);
    if (record == null || roundsWon == null) return record;
    return MatchRecord(
      id: record.id,
      mode: record.mode,
      playerFactionId: record.playerFactionId,
      opponentFactionId: record.opponentFactionId,
      opponentName: record.opponentName,
      outcome: record.outcome,
      roundsWon: roundsWon!,
      roundsLost: record.roundsLost,
      finishedAt: record.finishedAt,
      hasReplay: record.hasReplay,
    );
  }

  @override
  Future<ReplayLog?> findReplay(String recordId) async {
    if (corrupted) throw const ReplayCorrupted('испорчено');
    final log = await _inner.findReplay(recordId);
    if (log is! JournalReplayLog) return log;
    final journal = log.journal;
    final ruleset = journal.ruleset;
    return JournalReplayLog(
      net.MatchRecord(
        matchId: journal.matchId,
        ruleset: hash == null
            ? ruleset
            : net.Ruleset(id: ruleset.id, hash: hash!, engineVersion: ruleset.engineVersion),
        seed: journal.seed,
        one: journal.one,
        two: journal.two,
        moves: [...journal.moves, ?extraMove],
      ),
      perspective: log.perspective,
    );
  }
}
