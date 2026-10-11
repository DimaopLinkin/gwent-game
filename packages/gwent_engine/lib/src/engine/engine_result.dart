import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/engine/reject.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/match_state.dart';

/// Результат `apply` или `start`: новое состояние с событиями или отказ.
sealed class EngineResult extends Value {
  const EngineResult();
}

/// Намерение принято.
final class Accepted extends EngineResult {
  const Accepted(this.state, this.events);

  final MatchState state;

  /// Полные события; игроку их отдают через `eventsFor`.
  final List<GameEvent> events;

  @override
  List<Object?> get props => [state, events];
}

/// Намерение отклонено; состояние не изменилось.
final class Rejected extends EngineResult {
  const Rejected(this.reject);

  final Reject reject;

  @override
  List<Object?> get props => [reject];
}
