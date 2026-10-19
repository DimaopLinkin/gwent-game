import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart';

import 'decks.dart';
import 'fixtures.dart';

/// Кто сейчас должен действовать.
Seat actor(MatchState state) =>
    state.choice?.seat ??
    (state.phase == MatchPhase.redraw ? Seat.values.firstWhere((seat) => !state.player(seat).redrawDone) : state.turn!);

/// Партия двух ботов на колодах из фикстур с сидом [seed]; возвращает победителя или `null` при ничьей.
Seat? playBots(MatchBot one, MatchBot two, int seed) {
  var state = (engine.start(setupFor(seed)) as Accepted).state;
  final bots = {Seat.one: one, Seat.two: two};
  for (var step = 0; state.phase != MatchPhase.finished; step++) {
    if (step > 500) throw StateError('Партия с сидом $seed не закончилась за 500 шагов');
    final seat = actor(state);
    final intent = bots[seat]!.decide(state, seat) ?? (throw StateError('Бот за $seat промолчал (сид $seed)'));
    state = switch (engine.apply(state, seat, intent)) {
      Accepted(:final state) => state,
      Rejected(:final reject) => throw StateError('Движок отклонил $intent за $seat: ${reject.reason} (сид $seed)'),
    };
  }
  return state.outcome!.winner;
}

/// Результат матча сильного бота против слабого.
typedef Score = ({int wins, int losses, int draws});

/// Создаёт бота для партии с сидом `seed`.
typedef BotMaker = MatchBot Function(int seed);

/// Бот уровня [difficulty].
BotMaker level(BotDifficulty difficulty) =>
    (seed) => GreedyBot.forDifficulty(engine, catalog, difficulty, seed: seed);

/// Матч ботов [strong] и [weak]: каждый сид из [games] играется дважды с обменом мест, поэтому колоды и место
/// не решают исход.
Score versus(BotMaker strong, BotMaker weak, {required int games, int firstSeed = 0}) {
  var wins = 0;
  var losses = 0;
  var draws = 0;
  for (var seed = firstSeed; seed < firstSeed + games; seed++) {
    for (final strongSeat in Seat.values) {
      final bots = {strongSeat: strong(seed), strongSeat.opponent: weak(seed + 1000)};
      switch (playBots(bots[Seat.one]!, bots[Seat.two]!, seed)) {
        case final winner? when winner == strongSeat:
          wins++;
        case null:
          draws++;
        case _:
          losses++;
      }
    }
  }
  return (wins: wins, losses: losses, draws: draws);
}
