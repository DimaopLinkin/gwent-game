import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_builder.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_frame.dart';
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

  StageScript? build(
    PlayerView prev,
    PlayerView next,
    List<GameEvent> events, {
    StageStyle style = StageStyle.normal,
  }) => StageScriptBuilder(prev: prev, next: next, catalog: content.catalog, style: style).build(1, events);

  const mineMelee = (mine: true, row: Row.melee);

  group('розыгрыш отряда', () {
    test('моя карта прячется в ряду, летит из руки и ложится по концу сценария', () {
      final unit = cards.unit(Row.melee);
      final other = cards.unit(Row.ranged);
      final prev = viewOf(
        cards,
        me: sideOf(cards, Seat.one, hand: [unit, other]),
      );
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          hand: [other],
          rows: {
            Row.melee: rowOf([unit], cards),
          },
          score: cards.strength(unit),
        ),
      );
      final script = build(prev, next, [
        CardPlayed(Seat.one, unit),
        UnitPlaced(Seat.one, Row.melee, unit, EntrySource.hand),
      ])!;

      final start = script.frameAt(0);
      expect(start.rows[mineMelee]!.cards.single.hidden, isTrue, reason: 'карта ещё в полёте');
      expect(start.counters[(kind: StageCounter.hand, mine: true, row: null)]!.nearest, 2);
      expect(
        start.items.whereType<CardFlightItem>().single.from,
        isA<HandPlace>().having((place) => place.index, 'index', 0),
      );

      final end = script.frameAt(script.duration);
      expect(end.rows[mineMelee]!.cards.single.hidden, isFalse);
      expect(end.rows[mineMelee]!.cards.single.view.strength, cards.strength(unit));
      expect(end.items, isEmpty);
      expect(end.handVeil, 0);
      expect(end.counters[(kind: StageCounter.hand, mine: true, row: null)]!.settled, isTrue);
      expect(end.counters[(kind: StageCounter.hand, mine: true, row: null)]!.to, 1);
    });

    test('рука закрыта вуалью, пока идёт сценарий', () {
      final unit = cards.unit(Row.melee);
      final prev = viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit]));
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          hand: const [],
          rows: {
            Row.melee: rowOf([unit], cards),
          },
        ),
      );
      final script = build(prev, next, [
        CardPlayed(Seat.one, unit),
        UnitPlaced(Seat.one, Row.melee, unit, EntrySource.hand),
      ])!;
      expect(script.frameAt(10).handVeil, 1);
      expect(script.frameAt(script.duration).handVeil, 0);
    });

    test('карта соперника выходит крупно с подписью и только потом ложится', () {
      final unit = cards.unit(Row.melee);
      final prev = viewOf(cards, opponent: sideOf(cards, Seat.two, handCount: 5));
      final next = viewOf(
        cards,
        opponent: sideOf(
          cards,
          Seat.two,
          handCount: 4,
          rows: {
            Row.melee: rowOf([unit], cards),
          },
        ),
      );
      final script = build(prev, next, [
        CardPlayed(Seat.two, unit),
        UnitPlaced(Seat.two, Row.melee, unit, EntrySource.hand),
      ])!;
      final captions = <double>[
        for (var time = 0.0; time < script.duration; time += 20)
          if (script.frameAt(time).items.any((item) => item is CaptionItem)) time,
      ];
      expect(captions, isNotEmpty);
      const key = (mine: false, row: Row.melee);
      expect(script.frameAt(captions.first).rows[key]!.cards.every((card) => card.hidden), isTrue);
      expect(script.frameAt(script.duration).rows[key]!.cards.single.hidden, isFalse);
    });

    test('«Уменьшить движение»: ни полётов, ни прокрутки, карта проявляется на месте', () {
      final unit = cards.unit(Row.melee);
      final prev = viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit]));
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          hand: const [],
          rows: {
            Row.melee: rowOf([unit], cards),
          },
        ),
      );
      final script = build(
        prev,
        next,
        [CardPlayed(Seat.one, unit), UnitPlaced(Seat.one, Row.melee, unit, EntrySource.hand)],
        style: const StageStyle(reduceMotion: true),
      )!;
      for (var time = 0.0; time <= script.duration; time += 10) {
        final frame = script.frameAt(time);
        expect(frame.items.whereType<CardFlightItem>().every((item) => item.from == item.to), isTrue);
        expect(frame.counters.values.every((value) => value.progress == 1 || value.progress == 0), isTrue);
      }
    });

    test('быстрая скорость укорачивает сценарий', () {
      final unit = cards.unit(Row.melee);
      final prev = viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit]));
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          hand: const [],
          rows: {
            Row.melee: rowOf([unit], cards),
          },
        ),
      );
      final events = [CardPlayed(Seat.one, unit), UnitPlaced(Seat.one, Row.melee, unit, EntrySource.hand)];
      final normal = build(prev, next, events)!;
      final fast = build(prev, next, events, style: const StageStyle(scale: StageTokens.fastFactor))!;
      expect(fast.duration, lessThan(normal.duration * 0.7));
    });
  });

  group('особые карты', () {
    test('Казнь: цели горят, потом исчезают из ряда, сброс растёт', () {
      final scorch = cards.special<ScorchAbility>();
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
        opponent: sideOf(cards, Seat.two, handCount: 3, discard: [victim]),
      );
      final script = build(prev, next, [
        CardPlayed(Seat.one, scorch),
        UnitsDestroyed([DestroyedUnit(Seat.two, Row.melee, victim)]),
        CardDiscarded(Seat.two, victim),
        CardDiscarded(Seat.one, scorch),
      ])!;

      var burned = false;
      for (var time = 0.0; time < script.duration; time += 20) {
        if (script.frameAt(time).items.any((item) => item is BurnItem && item.burn > 0)) burned = true;
      }
      expect(burned, isTrue);
      expect(script.duration, lessThan(2800), reason: 'Казнь укладывается в бюджет макета с запасом на счётчик');
      final end = script.frameAt(script.duration);
      expect(end.rows[(mine: false, row: Row.melee)]!.cards, isEmpty);
      expect(end.discardTops[true], scorch);
      expect(end.discardTops[false], victim);
    });

    test('Казнь без целей показывает подпись «Нет подходящих целей»', () {
      final scorch = cards.special<ScorchAbility>();
      final prev = viewOf(cards, me: sideOf(cards, Seat.one, hand: [scorch]));
      final next = viewOf(
        cards,
        me: sideOf(cards, Seat.one, hand: const [], discard: [scorch]),
      );
      final script = build(prev, next, [CardPlayed(Seat.one, scorch), CardDiscarded(Seat.one, scorch)])!;
      final captions = <CaptionKind>{
        for (var time = 0.0; time < script.duration; time += 20)
          for (final item in script.frameAt(time).items.whereType<CaptionItem>()) item.kind,
      };
      expect(captions, contains(CaptionKind.noTargets));
    });

    test('погода: слот загорается к концу волны, силы отрядов меняются', () {
      final frost = cards.special<WeatherAbility>();
      final row = ((cards.definition(frost) as SpecialCardDefinition).ability as WeatherAbility).rows.first;
      final unit = cards.unit(row);
      final key = (mine: true, row: row);
      final strength = cards.strength(unit);
      final prev = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          hand: [frost],
          rows: {
            row: rowOf([unit], cards),
          },
        ),
      );
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          hand: const [],
          rows: {
            row: RowView(cards: [FieldCardView(card: unit, strength: 1)], slot: null, weather: true, strength: 1),
          },
          score: 1,
        ),
      );
      final script = build(prev, next, [CardPlayed(Seat.one, frost), WeatherPlayed(Seat.one, frost)])!;
      final start = script.frameAt(0);
      expect(start.rows[key]!.cards.single.view.strength, strength);
      expect(start.rows[key]!.weather, isFalse);
      final end = script.frameAt(script.duration);
      expect(end.rows[key]!.cards.single.view.strength, 1);
      expect(end.rows[key]!.weather, isTrue);
      expect(end.weatherSlots[row], isTrue);
    });
  });

  group('чего сборщик не берёт', () {
    test('обновление без розыгрыша не даёт сценария', () {
      final view = viewOf(cards);
      expect(build(view, view, const [TurnStarted(Seat.one)]), isNull);
    });

    test('конец раунда показывают другие сцены', () {
      final unit = cards.unit(Row.melee);
      final prev = viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit]));
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          rows: {
            Row.melee: rowOf([unit], cards),
          },
        ),
      );
      const result = RoundResult(round: 1, scores: {Seat.one: 5, Seat.two: 0}, winner: Seat.one);
      expect(
        build(prev, next, [
          CardPlayed(Seat.one, unit),
          UnitPlaced(Seat.one, Row.melee, unit, EntrySource.hand),
          const RoundEnded(result),
        ]),
        isNull,
      );
    });
  });
}
