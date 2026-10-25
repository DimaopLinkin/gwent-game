import 'package:gwent/src/features/replay/domain/replay_timeline.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart' as net;

/// Журнал не проигрывается: партия не начинается или движок отклоняет записанный ход.
final class JournalNotReplayable implements Exception {
  /// Создаёт ошибку с причиной [message].
  const JournalNotReplayable(this.message);

  /// Что не так.
  final String message;

  @override
  String toString() => 'JournalNotReplayable: $message';
}

/// Строит шкалу реплея из журнала: заново проигрывает партию движком и собирает кадр на каждый ход.
///
/// Видны оба места: журнал хранит сид и колоды обоих игроков, и у законченной партии скрывать нечего.
ReplayTimeline buildJournalTimeline(MatchEngine engine, net.MatchRecord journal, {required Seat perspective}) {
  ReplayFrame frame(MatchState state, List<GameEvent> events) => ReplayFrame(
    views: {for (final seat in Seat.values) seat: engine.project(state, seat)},
    events: {for (final seat in Seat.values) seat: engine.eventsFor(events, seat)},
  );

  final started = switch (engine.start(journal.setup)) {
    Accepted() && final accepted => accepted,
    Rejected(:final reject) => throw JournalNotReplayable('партия не начинается: ${reject.reason.name}'),
  };
  var state = started.state;
  final frames = [frame(state, started.events)];
  for (final (index, move) in journal.moves.indexed) {
    switch (engine.apply(state, move.seat, move.intent)) {
      case Accepted(state: final next, :final events):
        state = next;
        frames.add(frame(state, events));
      case Rejected(:final reject):
        throw JournalNotReplayable('ход $index отклонён: ${reject.reason.name}');
    }
  }
  return ReplayTimeline(frames: frames, seats: Seat.values.toSet(), perspective: perspective);
}
