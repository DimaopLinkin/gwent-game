import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/stage/last_move_board.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../../support/match_fixtures.dart';
import '../field/field_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late TestCards cards;

  setUpAll(() async => content = await loadBaseContent());
  setUp(() => cards = TestCards(content));

  RoundResult result(int mine, int theirs) =>
      RoundResult(round: 1, scores: {Seat.one: mine, Seat.two: theirs}, winner: Seat.one);

  PlayerView closingOf(CardInstance old, {List<CardInstance> hand = const [], int theirs = 0}) => viewOf(
    cards,
    me: sideOf(
      cards,
      Seat.one,
      hand: hand,
      rows: {
        Row.melee: rowOf([old], cards),
      },
      score: cards.strength(old),
    ),
    opponent: sideOf(cards, Seat.two, handCount: 3, score: theirs),
  );

  PlayerView? boardOf(PlayerView closing, List<GameEvent> moves, RoundResult result) =>
      boardAfterLastMove(closing: closing, moves: moves, result: result, catalog: content.catalog);

  test('отряд из руки встаёт в ряд, рука и счёт сходятся с итогом раунда', () {
    final old = cards.unit(Row.melee);
    final played = cards.unit(Row.melee);
    const bonus = 3;
    final score = cards.strength(old) + cards.strength(played) + bonus;
    final board = boardOf(
      closingOf(old, hand: [played]),
      [CardPlayed(Seat.one, played), UnitPlaced(Seat.one, Row.melee, played, EntrySource.hand)],
      result(score, 0),
    )!;

    expect(board.me.rows[Row.melee]!.cards.map((view) => view.card), [old, played]);
    expect(board.me.hand, isEmpty);
    expect(board.me.handCount, 0);
    expect(board.me.score, score);
    expect(
      board.me.rows[Row.melee]!.strength,
      score,
      reason: 'разница до точного счёта легла на ряд последнего отряда',
    );
  });

  test('ход соперника: рука скрыта, счётчик руки уменьшается, отряд встаёт на его сторону', () {
    final old = cards.unit(Row.melee);
    final played = cards.unit(Row.ranged);
    final board = boardOf(
      closingOf(old),
      [CardPlayed(Seat.two, played), UnitPlaced(Seat.two, Row.ranged, played, EntrySource.hand)],
      result(cards.strength(old), cards.strength(played)),
    )!;

    expect(board.opponent.hand, isNull);
    expect(board.opponent.handCount, 2);
    expect(board.opponent.rows[Row.ranged]!.cards.single.card, played);
    expect(board.opponent.score, cards.strength(played));
  });

  test('шпион: карта встаёт к сопернику, добор пополняет руку и убавляет колоду', () {
    final old = cards.unit(Row.melee);
    final spy = cards.spy();
    final drawn = cards.unit(Row.melee);
    final board = boardOf(
      closingOf(old, hand: [spy]),
      [
        CardPlayed(Seat.one, spy),
        UnitPlaced(Seat.two, Row.melee, spy, EntrySource.hand),
        CardsDrawn(Seat.one, [drawn]),
      ],
      result(cards.strength(old), cards.strength(spy)),
    )!;

    expect(board.opponent.rows[Row.melee]!.cards.single.card, spy);
    expect(board.me.hand, [drawn]);
    expect(board.me.handCount, 1);
    expect(board.me.deckCount, closingOf(old).me.deckCount - 1);
  });

  test('не отряд из руки: особая карта, лидер, Двойник и Медик поля не собирают', () {
    final old = cards.unit(Row.melee);
    final unit = cards.unit(Row.melee);
    final special = cards.special<ScorchAbility>();
    final closing = closingOf(old, hand: [unit]);

    expect(
      boardOf(closing, [CardPlayed(Seat.one, special)], result(0, 0)),
      isNull,
      reason: 'особая карта',
    );
    expect(
      boardOf(closing, [LeaderUsed(Seat.one, closing.me.leader)], result(0, 0)),
      isNull,
      reason: 'лидер без карты',
    );
    expect(
      boardOf(
        closing,
        [
          CardPlayed(Seat.one, unit),
          UnitPlaced(Seat.one, Row.melee, cards.unit(Row.melee), EntrySource.musterFromHand),
        ],
        result(0, 0),
      ),
      isNull,
      reason: 'Двойник',
    );
    expect(
      boardOf(
        closing,
        [CardPlayed(Seat.one, unit), UnitPlaced(Seat.one, Row.melee, cards.unit(Row.melee), EntrySource.medic)],
        result(0, 0),
      ),
      isNull,
      reason: 'Медик',
    );
  });

  test('карта, которая уже лежит на поле, значит, события повторяются: поле не собирают', () {
    final old = cards.unit(Row.melee);
    final board = boardOf(
      closingOf(old),
      [CardPlayed(Seat.one, old), UnitPlaced(Seat.one, Row.melee, old, EntrySource.hand)],
      result(0, 0),
    );
    expect(board, isNull);
  });
}
