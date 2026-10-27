import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/hand_order.dart';
import 'package:gwent/src/features/match/presentation/row_order.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../support/match_fixtures.dart';
import 'field/field_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late TestCards cards;
  late RowOrder order;

  setUpAll(() async => content = await loadBaseContent());
  setUp(() {
    cards = TestCards(content);
    order = RowOrder(HandOrder(content));
  });

  List<CardInstanceId> ids(PlayerView view, Row row, {bool mine = true}) => [
    for (final field in (mine ? view.me : view.opponent).rows[row]!.cards) field.card.id,
  ];

  test('карты ряда идут по возрастанию базовой силы, герой правее слабого отряда', () {
    final weak = cards.unit(Row.melee);
    final strong = cards.hero();
    final view = viewOf(
      cards,
      me: sideOf(
        cards,
        Seat.one,
        rows: {
          Row.melee: rowOf([strong, weak], cards),
        },
      ),
    );

    expect(ids(order.apply(view), Row.melee), [weak.id, strong.id]);
  });

  test('сила на столе порядок не меняет: усиление и погода карты не переставляют', () {
    final weak = cards.unit(Row.melee);
    final strong = cards.hero();
    final boosted = RowView(
      cards: [
        FieldCardView(card: weak, strength: cards.strength(weak) * 10),
        FieldCardView(card: strong, strength: 1),
      ],
      slot: null,
      weather: true,
      strength: 0,
    );
    final view = viewOf(cards, me: sideOf(cards, Seat.one, rows: {Row.melee: boosted}));

    final ordered = order.apply(view);

    expect(ids(ordered, Row.melee), [weak.id, strong.id]);
    expect(identical(ordered, view), isTrue, reason: 'порядок уже верный, проекция та же');
  });

  test('сортируются оба игрока и все ряды, остальное в проекции не меняется', () {
    final weak = cards.unit(Row.melee);
    final strong = cards.hero();
    final hand = [strong, weak];
    final view = viewOf(
      cards,
      me: sideOf(
        cards,
        Seat.one,
        hand: hand,
        score: 7,
        rows: {
          Row.melee: rowOf([strong, weak], cards, weather: true),
          Row.ranged: rowOf([strong, weak], cards),
        },
      ),
      opponent: sideOf(
        cards,
        Seat.two,
        rows: {
          Row.siege: rowOf([strong, weak], cards, slot: const LeaderHornSlot()),
        },
      ),
    );

    final ordered = order.apply(view);

    expect(ids(ordered, Row.melee), [weak.id, strong.id]);
    expect(ids(ordered, Row.ranged), [weak.id, strong.id]);
    expect(ids(ordered, Row.siege, mine: false), [weak.id, strong.id]);
    expect(ordered.me.hand, hand, reason: 'рука в проекции остаётся как есть: её порядок считает HandOrder');
    expect(ordered.me.score, 7);
    final melee = ordered.me.rows[Row.melee]!;
    expect(melee.weather, isTrue);
    expect(melee.strength, view.me.rows[Row.melee]!.strength);
    expect(ordered.opponent.rows[Row.siege]!.slot, const LeaderHornSlot());
    expect(ordered.viewer, view.viewer);
    expect(ordered.turn, view.turn);
  });

  test('копии одной карты стоят рядом и не прыгают от порядка прихода', () {
    final first = cards.unit(Row.melee);
    final middle = cards.hero();
    final second = cards.unit(Row.melee);
    final views = [
      for (final shuffled in [
        [first, middle, second],
        [second, middle, first],
        [middle, first, second],
      ])
        order.apply(viewOf(cards, me: sideOf(cards, Seat.one, rows: {Row.melee: rowOf(shuffled, cards)}))),
    ];

    for (final view in views) {
      expect(ids(view, Row.melee), [first.id, second.id, middle.id]);
    }
  });

  test('Чучело стоит на месте забранной карты, а незнакомое Чучело слева как особая карта', () {
    final first = cards.unit(Row.melee);
    final taken = cards.unit(Row.melee);
    final last = cards.hero();
    final decoy = cards.special<DecoyAbility>();
    RowView row() => RowView(
      cards: [
        FieldCardView(card: first, strength: cards.strength(first)),
        FieldCardView(card: decoy, strength: 0),
        FieldCardView(card: last, strength: cards.strength(last)),
      ],
      slot: null,
      weather: false,
      strength: 0,
    );
    final view = viewOf(cards, me: sideOf(cards, Seat.one, rows: {Row.melee: row()}));

    final known = RowOrder(HandOrder(content), replaced: {decoy.id: taken}).apply(view);
    final unknown = order.apply(view);

    expect(ids(known, Row.melee), [first.id, decoy.id, last.id]);
    expect(ids(unknown, Row.melee), [decoy.id, first.id, last.id]);
  });

  test('пустые ряды и пустое поле не ломаются', () {
    final view = viewOf(cards);

    expect(identical(order.apply(view), view), isTrue);
  });
}
