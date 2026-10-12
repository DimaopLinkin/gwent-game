import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'support/decks.dart';
import 'support/fixtures.dart';

/// Полные партии с ботом: бот никогда не делает нелегальных ходов и доигрывает партию до конца.
void main() {
  final bot = GreedyBot(engine, catalog);

  /// Кто сейчас должен действовать.
  Seat actor(MatchState state) =>
      state.choice?.seat ??
      (state.phase == MatchPhase.redraw
          ? Seat.values.firstWhere((seat) => !state.player(seat).redrawDone)
          : state.turn!);

  /// Простой соперник: перебирает намерения по кругу, пока движок не примет одно. Нужен, чтобы бот попадал
  /// в позиции, до которых не доходят партии бота с самим собой.
  Intent scripted(MatchState state, Seat seat, int step) {
    final candidates = <Intent>[];
    final choice = state.choice;
    if (choice != null) {
      candidates.add(ChooseOption(choice.options[step % choice.options.length]));
    } else if (state.phase == MatchPhase.redraw) {
      final hand = state.player(seat).hand;
      if (step.isEven) candidates.add(RedrawCard(hand[step % hand.length].id));
      candidates.add(const FinishRedraw());
    } else {
      final player = state.player(seat);
      if (step % 5 == 0) candidates.add(const UseLeader());
      if (step % 11 == 0) candidates.add(const Pass());
      final own = [for (final row in player.rows.values) ...row.cards.map((card) => card.card.id)];
      for (var i = 0; i < player.hand.length; i++) {
        final card = player.hand[(i + step) % player.hand.length].id;
        for (final row in [null, ...Row.values]) {
          candidates.add(PlayCard(card, row: row));
          for (final target in own) {
            candidates.add(PlayCard(card, row: row, target: target));
          }
        }
      }
      candidates.add(const Pass());
    }
    return candidates.firstWhere((intent) => engine.apply(state, seat, intent) is Accepted);
  }

  /// Играет партию; за места из [bots] ходит жадный бот, за остальные — простой соперник.
  ({MatchState state, List<Intent> intents}) play(int seed, Set<Seat> bots) {
    var state = (engine.start(setupFor(seed)) as Accepted).state;
    final intents = <Intent>[];
    for (var step = 0; state.phase != MatchPhase.finished; step++) {
      if (step > 500) fail('Партия с сидом $seed не закончилась за 500 шагов');
      final seat = actor(state);
      final Intent intent;
      if (bots.contains(seat)) {
        intent = bot.decide(state, seat) ?? fail('Бот за $seat промолчал на шаге $step (сид $seed)');
        if (state.phase == MatchPhase.playing && bots.contains(seat.opponent)) {
          expect(bot.decide(state, seat.opponent), isNull, reason: 'бот не ходит вне очереди (сид $seed, шаг $step)');
        }
      } else {
        intent = scripted(state, seat, step);
      }
      final result = engine.apply(state, seat, intent);
      if (result case Rejected(:final reject)) {
        fail('Движок отклонил $intent бота за $seat: ${reject.reason} (сид $seed, шаг $step)');
      }
      state = (result as Accepted).state;
      intents.add(intent);
    }
    expect(bot.decide(state, Seat.one), isNull, reason: 'после конца партии бот молчит');
    return (state: state, intents: intents);
  }

  test('бот против бота: все ходы допустимы, партии доигрываются', () {
    for (var seed = 0; seed < 60; seed++) {
      final match = play(seed, Seat.values.toSet());
      expect(match.state.outcome, isNotNull);
    }
  });

  test('бот против простого соперника: все ходы бота допустимы за обоих игроков', () {
    for (var seed = 0; seed < 60; seed++) {
      play(seed, {Seat.one});
      play(seed, {Seat.two});
    }
  });

  test('бот чаще выигрывает у простого соперника', () {
    var wins = 0;
    const games = 50;
    for (var seed = 0; seed < games; seed++) {
      final seat = seed.isEven ? Seat.one : Seat.two;
      if (play(seed, {seat}).state.outcome!.winner == seat) wins++;
    }
    expect(wins, greaterThan(games * 0.7));
  });

  test('бот детерминирован: одинаковые сид и колоды дают одинаковую партию', () {
    final first = play(7, Seat.values.toSet());
    final second = play(7, Seat.values.toSet());
    expect(second.intents, first.intents);
    expect(second.state, first.state);
  });
}
