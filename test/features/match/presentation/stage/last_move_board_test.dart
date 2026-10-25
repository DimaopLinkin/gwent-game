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

  group('поле движка в событии конца раунда', () {
    RoundBoard boardWith({
      required SideView mine,
      required SideView theirs,
      List<WeatherCard> weather = const [],
    }) => RoundBoard(weather: weather, sides: {mine.seat: mine, theirs.seat: theirs});

    PlayerView? boardFrom(PlayerView closing, List<GameEvent> moves, RoundBoard board) => boardAfterLastMove(
      closing: closing,
      moves: moves,
      result: result(0, 0),
      board: board,
      catalog: content.catalog,
    );

    test('Командирский рог последним ходом: слот, удвоенные силы и счёт берутся из поля движка', () {
      final old = cards.unit(Row.melee);
      final horn = cards.special<HornCardAbility>();
      final doubled = cards.strength(old) * 2;
      final closing = closingOf(old, hand: [horn]);
      final row = RowView(
        cards: [FieldCardView(card: old, strength: doubled)],
        slot: CardSlot(horn),
        weather: false,
        strength: doubled,
      );
      final board = boardFrom(
        closing,
        [CardPlayed(Seat.one, horn), SlotFilled(Seat.one, Row.melee, CardSlot(horn))],
        boardWith(
          mine: sideOf(cards, Seat.one, rows: {Row.melee: row}, score: doubled, passed: true),
          theirs: sideOf(cards, Seat.two, handCount: 3, passed: true),
        ),
      )!;

      expect(board.me.rows[Row.melee]!.slot, CardSlot(horn));
      expect(board.me.rows[Row.melee]!.strength, doubled);
      expect(board.me.rows[Row.melee]!.cards.single.strength, doubled);
      expect(board.me.score, doubled);
      expect(board.me.hand, isEmpty, reason: 'рог ушёл из руки');
      expect(board.me.crystals, closing.me.crystals, reason: 'камень теряет подсчёт, а не ход');
    });

    test('погода, Казнь, лидер, Чучело и Медик тоже дают поле', () {
      final old = cards.unit(Row.melee);
      final other = cards.unit(Row.ranged);
      final closing = closingOf(old, hand: [other]);
      final empty = boardWith(
        mine: sideOf(cards, Seat.one, passed: true),
        theirs: sideOf(cards, Seat.two, handCount: 3, passed: true),
      );
      final special = cards.special<ScorchAbility>();
      for (final moves in <List<GameEvent>>[
        [CardPlayed(Seat.one, special)],
        [LeaderUsed(Seat.one, closing.me.leader)],
        [CardPlayed(Seat.one, other), UnitDecoyed(Seat.one, Row.melee, decoy: other, returned: old)],
        [CardPlayed(Seat.one, other), UnitPlaced(Seat.one, Row.melee, cards.unit(Row.melee), EntrySource.medic)],
        [
          CardPlayed(Seat.one, other),
          UnitPlaced(Seat.one, Row.melee, cards.unit(Row.melee), EntrySource.musterFromHand),
        ],
      ]) {
        expect(boardFrom(closing, moves, empty), isNotNull, reason: '$moves');
      }
    });

    test('рука: возвращённое Чучелом пополняет её, сыгранное и добранное учитываются', () {
      final old = cards.unit(Row.melee);
      final decoy = cards.special<DecoyAbility>();
      final drawn = cards.unit(Row.ranged);
      final closing = closingOf(old, hand: [decoy]);
      final board = boardFrom(
        closing,
        [
          CardPlayed(Seat.one, decoy),
          UnitDecoyed(Seat.one, Row.melee, decoy: decoy, returned: old),
          CardsDrawn(Seat.one, [drawn]),
        ],
        boardWith(
          mine: sideOf(cards, Seat.one, passed: true),
          theirs: sideOf(cards, Seat.two, handCount: 3, passed: true),
        ),
      )!;
      expect(board.me.hand, [old, drawn]);
    });

    test('поле соперника скрывает его руку, погода и отбои берутся из поля движка', () {
      final old = cards.unit(Row.melee);
      final frost = cards.special<WeatherAbility>();
      final board = boardFrom(
        closingOf(old),
        [CardPlayed(Seat.two, frost), WeatherPlayed(Seat.two, frost)],
        boardWith(
          mine: sideOf(cards, Seat.one, passed: true),
          theirs: sideOf(cards, Seat.two, handCount: 2, passed: true),
          weather: [WeatherCard(frost, Seat.two)],
        ),
      )!;
      expect(board.weather.single.card, frost);
      expect(board.opponent.hand, isNull);
      expect(board.opponent.handCount, 2);
    });

    test('карта, которая уже лежит на поле, значит, события повторяются: поля нет', () {
      final old = cards.unit(Row.melee);
      expect(
        boardFrom(
          closingOf(old),
          [CardPlayed(Seat.one, old), UnitPlaced(Seat.one, Row.melee, old, EntrySource.hand)],
          boardWith(mine: sideOf(cards, Seat.one), theirs: sideOf(cards, Seat.two)),
        ),
        isNull,
      );
    });
  });
}
