import 'package:flutter/widgets.dart' hide Row;
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/field/field_geometry.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_beat.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_builder.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_frame.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_geometry.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_place.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_script.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../../support/match_fixtures.dart';
import '../field/field_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late TestCards cards;

  setUpAll(() async => content = await loadBaseContent());
  setUp(() => cards = TestCards(content));

  StageScript build(PlayerView prev, PlayerView next, List<GameEvent> events, {StageStyle? style}) =>
      StageScriptBuilder(
        prev: prev,
        next: next,
        catalog: content.catalog,
        style: style ?? StageStyle.normal,
      ).build(1, events)!;

  Iterable<double> times(StageScript script) sync* {
    for (var time = 0.0; time <= script.duration; time += 10) {
      yield time;
    }
    yield script.duration;
  }

  const opponentMelee = (mine: false, row: Row.melee);

  group('лидер', () {
    test('мини-карта лидера в центре занимает около 93×132, а не закрывает поле', () {
      final prev = viewOf(cards, me: sideOf(cards, Seat.one));
      final next = viewOf(cards, me: sideOf(cards, Seat.one, leaderUsed: true));
      final script = build(prev, next, [LeaderUsed(Seat.one, cards.leader)]);
      final geometry = StageGeometry(
        field: const FieldGeometry(width: 390),
        canvas: GlobalKey(),
        anchors: const {},
        projection: next,
      );
      var biggest = Size.zero;
      for (final time in times(script)) {
        final frame = script.frameAt(time);
        for (final item in frame.items.whereType<CardFlightItem>()) {
          final rect = geometry.rectOf(item.to, frame);
          if (rect == null || item.to is! MiniCenterPlace) continue;
          final size = Size(rect.width * item.scale, rect.height * item.scale);
          if (size.width > biggest.width) biggest = size;
        }
      }
      expect(biggest.width, closeTo(93, 1));
      expect(biggest.height, closeTo(132, 1));
    });

    test('карта погоды входит в слот без сплющивания', () {
      final geometry = StageGeometry(
        field: const FieldGeometry(width: 390),
        canvas: GlobalKey(),
        anchors: const {},
        projection: viewOf(cards),
      );
      final script = build(
        viewOf(cards, me: sideOf(cards, Seat.one, hand: [cards.unit(Row.melee)])),
        viewOf(cards, me: sideOf(cards, Seat.one, hand: [cards.unit(Row.melee)], leaderUsed: true)),
        [LeaderUsed(Seat.one, cards.leader)],
      );
      final rect = geometry.rectOf(const WeatherSlotPlace(Row.melee), script.frameAt(0))!;
      expect(rect.width / rect.height, closeTo(103 / 148, 0.01));
    });
  });

  group('Медик', () {
    test('шпиона Медик достаёт из своего сброса, а кладёт в ряд соперника', () {
      final medic = cards.medic();
      final spy = cards.spy();
      final prev = viewOf(
        cards,
        me: sideOf(cards, Seat.one, hand: [medic], discard: [spy]),
        opponent: sideOf(cards, Seat.two, handCount: 3),
      );
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          hand: const [],
          rows: {
            Row.melee: rowOf([medic], cards),
          },
        ),
        opponent: sideOf(
          cards,
          Seat.two,
          handCount: 3,
          rows: {
            Row.melee: rowOf([spy], cards),
          },
        ),
      );
      final script = build(prev, next, [
        CardPlayed(Seat.one, medic),
        UnitPlaced(Seat.one, Row.melee, medic, EntrySource.hand),
        UnitPlaced(Seat.two, Row.melee, spy, EntrySource.medic),
      ]);
      final fromDiscard = script.beats.whereType<FlightBeat>().where((beat) => beat.to is RowCardPlace);
      expect(fromDiscard.map((beat) => beat.from), contains(const DiscardPlace(mine: true)));
      expect(fromDiscard.map((beat) => beat.from), isNot(contains(const DiscardPlace(mine: false))));
      final discard = script.beats.whereType<CounterBeat>().where(
        (beat) => beat.key == (kind: StageCounter.discard, mine: true, row: null),
      );
      expect(discard.single.to, 0);
    });

    test('шпиона Медик соперника достаёт из сброса соперника, а кладёт в мой ряд', () {
      final medic = cards.medic();
      final spy = cards.spy();
      final prev = viewOf(
        cards,
        me: sideOf(cards, Seat.one),
        opponent: sideOf(cards, Seat.two, handCount: 3, discard: [spy]),
      );
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          rows: {
            Row.melee: rowOf([spy], cards),
          },
        ),
        opponent: sideOf(
          cards,
          Seat.two,
          handCount: 2,
          rows: {
            Row.melee: rowOf([medic], cards),
          },
        ),
      );
      final script = build(prev, next, [
        CardPlayed(Seat.two, medic),
        UnitPlaced(Seat.two, Row.melee, medic, EntrySource.hand),
        UnitPlaced(Seat.one, Row.melee, spy, EntrySource.medic),
      ]);
      final flights = script.beats.whereType<FlightBeat>().where(
        (beat) => beat.to is RowCardPlace && (beat.to as RowCardPlace).card == spy.id && beat.from is! RowCardPlace,
      );
      expect(flights.map((beat) => beat.from), [const DiscardPlace(mine: false)]);
    });

    test('Медик соперника кладёт обычный отряд из его сброса в его ряд', () {
      final medic = cards.medic();
      final revived = cards.unit(Row.melee);
      final prev = viewOf(
        cards,
        me: sideOf(cards, Seat.one),
        opponent: sideOf(cards, Seat.two, handCount: 3, discard: [revived]),
      );
      final next = viewOf(
        cards,
        me: sideOf(cards, Seat.one),
        opponent: sideOf(
          cards,
          Seat.two,
          handCount: 2,
          rows: {
            Row.melee: rowOf([medic, revived], cards),
          },
        ),
      );
      final script = build(prev, next, [
        CardPlayed(Seat.two, medic),
        UnitPlaced(Seat.two, Row.melee, medic, EntrySource.hand),
        UnitPlaced(Seat.two, Row.melee, revived, EntrySource.medic),
      ]);
      final flights = script.beats.whereType<FlightBeat>().where(
        (beat) => beat.to is RowCardPlace && (beat.to as RowCardPlace).card == revived.id && beat.from is! RowCardPlace,
      );
      expect(flights.map((beat) => beat.from), [const DiscardPlace(mine: false)]);
    });

    group('отдельным обновлением, без розыгрыша карты', () {
      Iterable<StagePlace> fromOf(StageScript script, CardInstance card) => script.beats
          .whereType<FlightBeat>()
          .where((beat) => beat.to is RowCardPlace && (beat.to as RowCardPlace).card == card.id)
          .where((beat) => beat.from is! RowCardPlace)
          .map((beat) => beat.from);

      test('шпион соперника из его сброса ложится в мой ряд', () {
        final spy = cards.spy();
        final prev = viewOf(
          cards,
          me: sideOf(cards, Seat.one),
          opponent: sideOf(cards, Seat.two, handCount: 3, discard: [spy]),
        );
        final next = viewOf(
          cards,
          me: sideOf(
            cards,
            Seat.one,
            rows: {
              Row.melee: rowOf([spy], cards),
            },
          ),
          opponent: sideOf(cards, Seat.two, handCount: 3),
        );
        final script = build(prev, next, [UnitPlaced(Seat.one, Row.melee, spy, EntrySource.medic)]);
        expect(fromOf(script, spy), [const DiscardPlace(mine: false)]);
      });

      test('мой шпион из моего сброса ложится в ряд соперника', () {
        final spy = cards.spy();
        final prev = viewOf(
          cards,
          me: sideOf(cards, Seat.one, discard: [spy]),
          opponent: sideOf(cards, Seat.two, handCount: 3),
        );
        final next = viewOf(
          cards,
          me: sideOf(cards, Seat.one),
          opponent: sideOf(
            cards,
            Seat.two,
            handCount: 3,
            rows: {
              Row.melee: rowOf([spy], cards),
            },
          ),
        );
        final script = build(prev, next, [UnitPlaced(Seat.two, Row.melee, spy, EntrySource.medic)]);
        expect(fromOf(script, spy), [const DiscardPlace(mine: true)]);
      });

      test('шпион, сгоревший на ряду соперника, возвращается из сброса того, на чьей стороне сгорел', () {
        final scorch = cards.special<ScorchAbility>();
        final spy = cards.spy();
        final prev = viewOf(
          cards,
          me: sideOf(cards, Seat.one, hand: [scorch]),
          opponent: sideOf(
            cards,
            Seat.two,
            handCount: 3,
            rows: {
              Row.melee: rowOf([spy], cards),
            },
          ),
        );
        final next = viewOf(
          cards,
          me: sideOf(
            cards,
            Seat.one,
            discard: [scorch],
            rows: {
              Row.melee: rowOf([spy], cards),
            },
          ),
          opponent: sideOf(cards, Seat.two, handCount: 3),
        );
        final script = build(prev, next, [
          CardPlayed(Seat.one, scorch),
          UnitsDestroyed([DestroyedUnit(Seat.two, Row.melee, spy)]),
          CardDiscarded(Seat.two, spy),
          CardDiscarded(Seat.one, scorch),
          UnitPlaced(Seat.one, Row.melee, spy, EntrySource.medic),
        ]);
        expect(fromOf(script, spy), [const DiscardPlace(mine: false)]);
      });

      test('обычный отряд возвращается из сброса своей стороны', () {
        final unit = cards.unit(Row.melee);
        final prev = viewOf(
          cards,
          me: sideOf(cards, Seat.one),
          opponent: sideOf(cards, Seat.two, handCount: 3, discard: [unit]),
        );
        final next = viewOf(
          cards,
          me: sideOf(cards, Seat.one),
          opponent: sideOf(
            cards,
            Seat.two,
            handCount: 3,
            rows: {
              Row.melee: rowOf([unit], cards),
            },
          ),
        );
        final script = build(prev, next, [UnitPlaced(Seat.two, Row.melee, unit, EntrySource.medic)]);
        expect(fromOf(script, unit), [const DiscardPlace(mine: false)]);
      });
    });

    test('силы ряда и счёт меняются после посадки оживлённой карты, а не раньше', () {
      final medic = cards.medic();
      final revived = cards.unit(Row.melee);
      final prev = viewOf(
        cards,
        me: sideOf(cards, Seat.one, hand: [medic], discard: [revived]),
      );
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          hand: const [],
          rows: {
            Row.melee: rowOf([medic, revived], cards),
          },
          score: cards.strength(medic) + cards.strength(revived),
        ),
      );
      final script = build(prev, next, [
        CardPlayed(Seat.one, medic),
        UnitPlaced(Seat.one, Row.melee, medic, EntrySource.hand),
        UnitPlaced(Seat.one, Row.melee, revived, EntrySource.medic),
      ]);
      final lastLanding = script.beats
          .whereType<FlightBeat>()
          .where((beat) => beat.to is RowCardPlace)
          .map((beat) => beat.end)
          .reduce((a, b) => a > b ? a : b);
      final score = script.beats.whereType<CounterBeat>().firstWhere(
        (beat) => beat.key == (kind: StageCounter.rowScore, mine: true, row: Row.melee),
      );
      expect(score.start, greaterThanOrEqualTo(lastLanding - 1));
    });
  });

  group('несколько ходов в одном обновлении (hot-seat)', () {
    test('Казнь сжигает карту, Медик возвращает её: после сгорания она снова в ряду и не двоится', () {
      final scorch = cards.special<ScorchAbility>();
      final medic = cards.medic();
      final victim = cards.unit(Row.melee);
      final prev = viewOf(
        cards,
        me: sideOf(cards, Seat.one, hand: [scorch]),
        opponent: sideOf(
          cards,
          Seat.two,
          handCount: 3,
          rows: {
            Row.melee: rowOf([victim], cards),
          },
        ),
      );
      final next = viewOf(
        cards,
        me: sideOf(cards, Seat.one, hand: const [], discard: [scorch]),
        opponent: sideOf(
          cards,
          Seat.two,
          handCount: 2,
          rows: {
            Row.melee: rowOf([medic, victim], cards),
          },
        ),
      );
      final script = build(prev, next, [
        CardPlayed(Seat.one, scorch),
        UnitsDestroyed([DestroyedUnit(Seat.two, Row.melee, victim)]),
        CardDiscarded(Seat.two, victim),
        CardDiscarded(Seat.one, scorch),
        const TurnStarted(Seat.two),
        CardPlayed(Seat.two, medic),
        UnitPlaced(Seat.two, Row.melee, medic, EntrySource.hand),
        UnitPlaced(Seat.two, Row.melee, victim, EntrySource.medic),
      ]);

      var burning = false;
      for (final time in times(script)) {
        final frame = script.frameAt(time);
        final row = frame.rows[opponentMelee]!.cards;
        final shown = row.where((staged) => staged.view.card.id == victim.id && !staged.hidden).length;
        expect(row.where((staged) => staged.view.card.id == victim.id).length, lessThanOrEqualTo(1), reason: '$time');
        final burn = frame.items.whereType<BurnItem>().any((item) => item.burn > 0);
        burning |= burn;
        if (burn) expect(shown, 0, reason: 'горящая карта не лежит в ряду, $time');
      }
      expect(burning, isTrue);

      final end = script.frameAt(script.duration).rows[opponentMelee]!.cards;
      expect(end.map((staged) => staged.view.card.id), [medic.id, victim.id]);
      expect(end.every((staged) => !staged.hidden), isTrue);
    });

    test('Казнь по карте, которая к концу вернулась на то же место, всё равно показывается', () {
      final scorch = cards.special<ScorchAbility>();
      final victim = cards.unit(Row.melee);
      final row = {
        Row.melee: rowOf([victim], cards),
      };
      final prev = viewOf(
        cards,
        me: sideOf(cards, Seat.one, hand: [scorch]),
        opponent: sideOf(cards, Seat.two, handCount: 3, rows: row),
      );
      final next = viewOf(
        cards,
        me: sideOf(cards, Seat.one, hand: const [], discard: [scorch]),
        opponent: sideOf(cards, Seat.two, handCount: 3, rows: row),
      );
      final script = build(prev, next, [
        CardPlayed(Seat.one, scorch),
        UnitsDestroyed([DestroyedUnit(Seat.two, Row.melee, victim)]),
        UnitPlaced(Seat.two, Row.melee, victim, EntrySource.medic),
      ]);
      expect(script.rows.keys, contains(opponentMelee), reason: 'ряд меняется по ходу сценария');
      for (final time in times(script)) {
        final frame = script.frameAt(time);
        final burn = frame.items.whereType<BurnItem>().any((item) => item.burn > 0);
        final lying = frame.rows[opponentMelee]!.cards.any((c) => c.view.card.id == victim.id && !c.hidden);
        if (burn) expect(lying, isFalse, reason: 'под огнём в ряду пусто, $time');
      }
    });
  });

  group('созданные карты', () {
    test('Казнь по созданной карте не кладёт её в сброс', () {
      final scorch = cards.special<ScorchAbility>();
      final token = cards.created();
      final prev = viewOf(
        cards,
        me: sideOf(cards, Seat.one, hand: [scorch]),
        opponent: sideOf(
          cards,
          Seat.two,
          handCount: 3,
          rows: {
            Row.melee: rowOf([token], cards),
          },
        ),
      );
      final next = viewOf(
        cards,
        me: sideOf(cards, Seat.one, hand: const [], discard: [scorch]),
        opponent: sideOf(cards, Seat.two, handCount: 3),
      );
      final script = build(prev, next, [
        CardPlayed(Seat.one, scorch),
        UnitsDestroyed([DestroyedUnit(Seat.two, Row.melee, token)]),
        CardLeftGame(token),
        CardDiscarded(Seat.one, scorch),
      ]);
      for (final time in times(script)) {
        final frame = script.frameAt(time);
        expect(
          frame.items.whereType<CardFlightItem>().any((item) => item.to == const DiscardPlace(mine: false)),
          isFalse,
        );
        expect(frame.discardTops[false], isNull);
        final counter = frame.counters[(kind: StageCounter.discard, mine: false, row: null)];
        expect(counter == null || counter.to == 0, isTrue);
      }
    });
  });

  group('рог в занятый слот', () {
    test('карта показывается и летит в свой отбой, слот остаётся прежним', () {
      final horn = cards.special<HornCardAbility>();
      final held = cards.special<HornCardAbility>();
      final held0 = RowView(cards: const [], slot: CardSlot(held), weather: false, strength: 0);
      final prev = viewOf(
        cards,
        me: sideOf(cards, Seat.one, hand: [horn], rows: {Row.melee: held0}),
      );
      final next = viewOf(
        cards,
        me: sideOf(cards, Seat.one, hand: const [], discard: [horn], rows: {Row.melee: held0}),
      );
      final script = build(prev, next, [CardPlayed(Seat.one, horn), CardDiscarded(Seat.one, horn)]);

      var flew = false;
      for (final time in times(script)) {
        final frame = script.frameAt(time);
        flew |= frame.items.whereType<CardFlightItem>().any((item) => item.to == const DiscardPlace(mine: true));
        expect(frame.rows[(mine: true, row: Row.melee)]?.slot ?? CardSlot(held), CardSlot(held), reason: '$time');
      }
      expect(flew, isTrue);
      expect(script.frameAt(script.duration).discardTops[true]?.id, horn.id);
    });
  });

  group('длинный ряд', () {
    test('волна сил по ряду не длиннее 600 мс', () {
      final horn = cards.special<HornCardAbility>();
      final units = [for (var i = 0; i < 20; i++) cards.unit(Row.melee)];
      final prev = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          hand: [horn],
          rows: {
            Row.melee: rowOf(units, cards),
          },
        ),
      );
      final doubled = RowView(
        cards: [for (final unit in units) FieldCardView(card: unit, strength: cards.strength(unit) * 2)],
        slot: CardSlot(horn),
        weather: false,
        strength: units.fold(0, (sum, unit) => sum + cards.strength(unit) * 2),
      );
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          hand: const [],
          rows: {Row.melee: doubled},
        ),
      );
      final script = build(prev, next, [
        CardPlayed(Seat.one, horn),
        SlotFilled(Seat.one, Row.melee, CardSlot(horn)),
      ]);
      final spec = script.rows[(mine: true, row: Row.melee)]!;
      final starts = [
        for (final phase in spec.phases)
          if (phase.strengthAt.isFinite) phase.strengthAt,
      ];
      expect(starts, isNotEmpty);
      expect(starts.reduce((a, b) => a > b ? a : b) - starts.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(600));
    });
  });
}
