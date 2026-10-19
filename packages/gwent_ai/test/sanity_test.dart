import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/match_builder.dart';

/// Уровни без намеренных промахов (все, кроме лёгкого) не тратят карты впустую и не вредят себе, даже когда экономят.
void main() {
  const me = Seat.one;
  final levels = BotDifficulty.values.where((difficulty) => difficulty != BotDifficulty.easy);

  /// Карта, которую бот кладёт в позиции [state].
  CardId played(MatchState state, BotDifficulty difficulty) {
    final intent = GreedyBot.forDifficulty(engine, catalog, difficulty).decide(state, me) ?? fail('Бот промолчал');
    if (intent is! PlayCard) fail('Ожидался розыгрыш карты, а бот выбрал $intent');
    return state.player(me).hand.firstWhere((card) => card.id == intent.card).cardId;
  }

  for (final difficulty in levels) {
    group(difficulty.name, () {
      test('Рог на пустой ряд не кладёт, пока есть сильный отряд', () {
        final state = playing(
          one: const Side(hand: ['horn', 'geralt']),
          two: const Side(melee: ['footman']),
        );
        expect(played(state, difficulty), const CardId('geralt'));
      });

      test('Рог на пустой ряд не кладёт и при малом приросте лучшего хода', () {
        final state = playing(
          one: const Side(hand: ['horn', 'archer_medic']),
          two: const Side(melee: ['footman']),
        );
        expect(played(state, difficulty), const CardId('archer_medic'));
      });

      test('погоду, которая бьёт только по своим отрядам, не кладёт', () {
        final state = playing(
          one: const Side(hand: ['frost', 'geralt'], melee: ['vesemir']),
        );
        expect(played(state, difficulty), const CardId('geralt'));
      });

      test('Казнью не убивает свою сильнейшую карту, когда у соперника слабее', () {
        final state = playing(
          one: const Side(hand: ['scorch', 'geralt'], melee: ['vesemir']),
          two: const Side(melee: ['footman']),
        );
        expect(played(state, difficulty), const CardId('geralt'));
      });
    });
  }
}
