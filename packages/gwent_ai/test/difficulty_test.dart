import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/match_builder.dart';
import 'support/tournament.dart';

/// Уровни сложности: каждый следующий выигрывает у предыдущего, партии доигрываются и повторяются по сиду.
void main() {
  /// Сколько сидов играется в каждом матче уровней; каждый сид играется дважды с обменом мест.
  const seeds = 100;

  for (final (strong, weak) in [
    (BotDifficulty.normal, BotDifficulty.easy),
    (BotDifficulty.hard, BotDifficulty.normal),
    (BotDifficulty.deathMatch, BotDifficulty.hard),
    (BotDifficulty.deathMatch, BotDifficulty.easy),
  ]) {
    test('${strong.name} выигрывает у ${weak.name} чаще, чем проигрывает', () {
      final score = versus(level(strong), level(weak), games: seeds);
      expect(score.wins, greaterThan(score.losses), reason: '$strong против $weak: $score');
    });
  }

  for (final difficulty in BotDifficulty.values) {
    test('${difficulty.name}: ходы допустимы, партии доигрываются, сид повторяет партию', () {
      for (var seed = 0; seed < 40; seed++) {
        final first = playBots(level(difficulty)(seed), level(difficulty)(seed + 1), seed);
        final second = playBots(level(difficulty)(seed), level(difficulty)(seed + 1), seed);
        expect(second, first, reason: 'сид $seed');
      }
    });
  }

  test('ошибки лёгкого уровня зависят от сида бота', () {
    final state = playing(
      one: const Side(hand: ['geralt', 'footman', 'vesemir', 'archer', 'dandelion']),
      two: const Side(melee: ['footman']),
    );
    Intent? decide(int seed) =>
        GreedyBot.forDifficulty(engine, catalog, BotDifficulty.easy, seed: seed).decide(state, Seat.one);

    expect({for (var seed = 0; seed < 20; seed++) decide(seed)}.length, greaterThan(1));
    expect(decide(3), decide(3));
  });
}
