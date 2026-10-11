import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/protocol/ruleset.dart';

/// Ход в журнале: кто и какое намерение отправил; в журнал попадают только принятые движком намерения.
final class RecordedMove extends Value {
  const RecordedMove(this.seat, this.intent);

  final Seat seat;
  final Intent intent;

  @override
  List<Object?> get props => [seat, intent];
}

/// Журнал партии хоста: всё, из чего движок заново строит партию (раздел 3.3 сетевой спецификации).
///
/// Движок детерминирован, поэтому сид, колоды и принятые намерения однозначно задают каждое состояние
/// и каждое событие. Журнал нужен для восстановления хоста после падения и для баг-репортов.
final class MatchRecord extends Value {
  const MatchRecord({
    required this.matchId,
    required this.ruleset,
    required this.seed,
    required this.one,
    required this.two,
    this.moves = const [],
  });

  final String matchId;
  final Ruleset ruleset;

  /// Сид `SeededRng` партии.
  final int seed;

  /// Колода игрока 1.
  final Deck one;

  /// Колода игрока 2.
  final Deck two;
  final List<RecordedMove> moves;

  MatchSetup get setup => MatchSetup(one: one, two: two, rng: SeededRng(seed));

  MatchRecord adding(RecordedMove move) => MatchRecord(
    matchId: matchId,
    ruleset: ruleset,
    seed: seed,
    one: one,
    two: two,
    moves: List.unmodifiable([...moves, move]),
  );

  /// Заново проигрывает партию. Ошибка [StateError] значит, что журнал не от этого движка или испорчен.
  MatchState replay(MatchEngine engine) {
    var state = switch (engine.start(setup)) {
      Accepted(:final state) => state,
      Rejected(:final reject) => throw StateError('Журнал $matchId: партия не начинается: $reject'),
    };
    for (final (index, move) in moves.indexed) {
      state = switch (engine.apply(state, move.seat, move.intent)) {
        Accepted(:final state) => state,
        Rejected(:final reject) => throw StateError('Журнал $matchId: ход $index ($move) отклонён: $reject'),
      };
    }
    return state;
  }

  @override
  List<Object?> get props => [matchId, ruleset, seed, one, two, moves];
}
