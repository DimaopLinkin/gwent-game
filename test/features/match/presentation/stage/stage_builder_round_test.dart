import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/field/round_summary.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_beat.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_builder.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_frame.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_place.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_script.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../../support/match_fixtures.dart';
import '../field/field_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late TestCards cards;

  setUpAll(() async => content = await loadBaseContent());
  setUp(() => cards = TestCards(content));

  RoundSummary summaryOf({
    RoundOutcome outcome = RoundOutcome.win,
    int mine = 0,
    int theirs = 0,
    List<FactionMark> marks = const [],
  }) => RoundSummary(
    round: 1,
    mineSeat: Seat.one,
    scoreMine: mine,
    scoreOpponent: theirs,
    outcome: outcome,
    crystalsMine: 2,
    crystalsOpponent: 1,
    mineFaction: Faction.skellige,
    opponentFaction: Faction.skellige,
    marks: marks,
  );

  /// Поле до конца раунда: у меня два отряда в ближнем ряду и один в дальнем, у соперника один в ближнем.
  ({PlayerView closing, PlayerView next, List<CardInstance> mine, CardInstance theirs, int mineScore, int theirScore})
  round() {
    final a = cards.unit(Row.melee);
    final b = cards.unit(Row.melee);
    final c = cards.unit(Row.ranged);
    final d = cards.unit(Row.melee);
    final mineScore = cards.strength(a) + cards.strength(b) + cards.strength(c);
    final theirScore = cards.strength(d);
    final closing = viewOf(
      cards,
      me: sideOf(
        cards,
        Seat.one,
        hand: [cards.unit(Row.melee)],
        rows: {
          Row.melee: rowOf([a, b], cards),
          Row.ranged: rowOf([c], cards),
        },
        score: mineScore,
      ),
      opponent: sideOf(
        cards,
        Seat.two,
        handCount: 5,
        rows: {
          Row.melee: rowOf([d], cards),
        },
        score: theirScore,
      ),
    );
    final next = viewOf(
      cards,
      me: sideOf(cards, Seat.one, hand: closing.me.hand, discard: [a, b, c]),
      opponent: sideOf(cards, Seat.two, handCount: 5, discard: [d], crystals: 1),
      round: 2,
    );
    return (closing: closing, next: next, mine: [a, b, c], theirs: d, mineScore: mineScore, theirScore: theirScore);
  }

  List<GameEvent> roundEvents(int mine, int theirs, {Seat? winner = Seat.one}) => [
    const Passed(Seat.one, auto: false),
    RoundEnded(RoundResult(round: 1, scores: {Seat.one: mine, Seat.two: theirs}, winner: winner)),
    const RoundStarted(2, Seat.two),
    const TurnStarted(Seat.two),
  ];

  StageScript build(
    ({PlayerView closing, PlayerView next, List<CardInstance> mine, CardInstance theirs, int mineScore, int theirScore})
    game,
    List<GameEvent> events,
    RoundSummary summary, {
    StageStyle style = StageStyle.normal,
  }) => StageScriptBuilder(
    prev: game.closing,
    next: game.next,
    catalog: content.catalog,
    style: style,
  ).buildRound(1, events, summary: summary)!;

  Iterable<double> times(StageScript script) sync* {
    for (var time = 0.0; time <= script.duration; time += 10) {
      yield time;
    }
    yield script.duration;
  }

  const mineMelee = (mine: true, row: Row.melee);
  const theirMelee = (mine: false, row: Row.melee);

  group('конец раунда', () {
    test('сначала поле раунда как оно было, в конце очищенное поле нового раунда', () {
      final game = round();
      final script = build(
        game,
        roundEvents(game.mineScore, game.theirScore),
        summaryOf(mine: game.mineScore, theirs: game.theirScore),
      );
      final start = script.frameAt(0);
      expect(start.rows[mineMelee]!.cards.map((card) => card.view.card), game.mine.take(2));
      expect(start.rows[theirMelee]!.cards.single.view.card, game.theirs);
      expect(start.rows[mineMelee]!.cards.every((card) => !card.hidden), isTrue);
      final end = script.frameAt(script.duration);
      expect(end.rows[mineMelee]!.cards, isEmpty);
      expect(end.rows[theirMelee]!.cards, isEmpty);
      expect(end.counters[(kind: StageCounter.total, mine: true, row: null)]!.to, 0);
      expect(end.counters[(kind: StageCounter.discard, mine: true, row: null)]!.to, 3);
      expect(end.counters[(kind: StageCounter.discard, mine: false, row: null)]!.to, 1);
      expect(end.discardTops[true], game.mine.last);
    });

    test('подсчёт: ряды подсвечиваются по одному, счёт растёт до итога, поле ничем не закрыто', () {
      final game = round();
      final script = build(
        game,
        roundEvents(game.mineScore, game.theirScore),
        summaryOf(mine: game.mineScore, theirs: game.theirScore),
      );
      final washed = <RowPlace>{};
      CountItem? last;
      for (final time in times(script)) {
        final frame = script.frameAt(time);
        if (time < 1700) {
          washed.addAll(
            frame.items
                .whereType<GlowItem>()
                .where((glow) => glow.kind == GlowKind.wash)
                .map((g) => g.place)
                .whereType(),
          );
          expect(frame.items.whereType<ScrimItem>(), isEmpty);
        }
        last = frame.items.whereType<CountItem>().firstOrNull ?? last;
      }
      expect(washed, hasLength(3), reason: 'три ряда с картами: у меня два, у соперника один');
      expect(last, isNotNull);
      final shown = script.frameAt(1500).items.whereType<CountItem>().single;
      expect(shown.mine.to, game.mineScore);
      expect(shown.theirs.to, game.theirScore);
      expect(shown.winner, RoundOutcome.win);
      expect(script.frameAt(100).items.whereType<CountItem>(), isEmpty, reason: 'первые 300 мс поле только замерло');
    });

    test('плашка итога стоит 1,2 с, поле под ней остаётся, тап её не ускоряет', () {
      final game = round();
      final marks = [
        const FactionMark(seat: Seat.one, mine: true, faction: Faction.northernRealms, kind: FactionMarkKind.extraCard),
      ];
      final script = build(
        game,
        roundEvents(game.mineScore, game.theirScore),
        summaryOf(mine: game.mineScore, theirs: game.theirScore, marks: marks),
      );
      final plaque = script.frameAt(2300).items.whereType<PlaqueItem>().single;
      expect(plaque.alpha, 1);
      expect(plaque.scaleY, 1);
      expect(plaque.marks.single, 1, reason: 'строка фракции вышла на 1950 мс');
      expect(script.frameAt(1760).items.whereType<PlaqueItem>().single.scaleY, lessThan(1));
      expect(script.frameAt(2950).items.whereType<PlaqueItem>(), isEmpty);
      expect(script.tapSpeedsUp(2000), isFalse);
      expect(script.tapSpeedsUp(600), isTrue);
      expect(script.frameAt(2300).items.whereType<ScrimItem>(), isEmpty);
    });

    test('проигравший теряет камень, полоса вздрагивает; победитель камней не теряет', () {
      final game = round();
      final script = build(
        game,
        roundEvents(game.mineScore, game.theirScore),
        summaryOf(mine: game.mineScore, theirs: game.theirScore),
      );
      final during = script.frameAt(2450);
      expect(during.gems[false]!.remaining, 1);
      expect(during.gems[false]!.progress, inInclusiveRange(0.01, 0.99));
      expect(during.gems.containsKey(true), isFalse);
      expect(during.shakes[false], isNotNull);
      expect(script.frameAt(2950).gems[false]!.progress, 1);
      expect(script.frameAt(2950).shakes[false], isNull);
    });

    test('ничья: камень теряют оба', () {
      final game = round();
      final script = build(
        game,
        roundEvents(10, 10, winner: null),
        summaryOf(outcome: RoundOutcome.draw, mine: 10, theirs: 10),
      );
      final frame = script.frameAt(2450);
      expect(frame.gems.keys, containsAll([true, false]));
    });

    test('Приманка при уборке поля: созданная карта встаёт после ухода остальных, а не с первого кадра', () {
      final game = round();
      final created = cards.unit(Row.melee);
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          hand: game.closing.me.hand,
          discard: game.mine,
          rows: {
            Row.melee: rowOf([created], cards),
          },
        ),
        opponent: game.next.opponent,
        round: 2,
      );
      final script = StageScriptBuilder(prev: game.closing, next: next, catalog: content.catalog).buildRound(
        1,
        [
          ...roundEvents(game.mineScore, game.theirScore).take(2),
          CreatedCardPlaced(Seat.one, Row.melee, created),
          const RoundStarted(2, Seat.two),
          const TurnStarted(Seat.two),
        ],
        summary: summaryOf(mine: game.mineScore, theirs: game.theirScore),
      )!;
      bool shown(double time) =>
          script.frameAt(time).rows[mineMelee]?.cards.any((card) => card.view.card == created && !card.hidden) ?? false;
      expect(shown(1000), isFalse, reason: 'на подсчёте новой карты ещё нет');
      expect(shown(2500), isFalse, reason: 'и под плашкой её нет');
      expect(shown(script.duration), isTrue);
    });

    test('строки способностей успевают появиться до ухода плашки, даже если их четыре', () {
      final game = round();
      const mark = FactionMark(seat: Seat.one, mine: true, faction: Faction.skellige, kind: FactionMarkKind.extraCard);
      final script = build(
        game,
        roundEvents(game.mineScore, game.theirScore),
        summaryOf(mine: game.mineScore, theirs: game.theirScore, marks: const [mark, mark, mark, mark]),
      );
      final plaque = script.beats.whereType<PlaqueBeat>().single;
      expect(plaque.markStarts, hasLength(4));
      expect(plaque.markStarts.last, lessThan(plaque.end - 200));
    });

    test('раунд без карт на поле: счёт нулевой, плашка всё равно показывается', () {
      final closing = viewOf(cards, opponent: sideOf(cards, Seat.two, handCount: 5));
      final next = viewOf(cards, opponent: sideOf(cards, Seat.two, handCount: 5, crystals: 1), round: 2);
      final script = StageScriptBuilder(prev: closing, next: next, catalog: content.catalog).buildRound(
        1,
        roundEvents(0, 0, winner: null),
        summary: summaryOf(outcome: RoundOutcome.draw),
      )!;
      expect(script.frameAt(1000).items.whereType<CountItem>().single.mine.to, 0);
      expect(script.frameAt(2200).items.whereType<PlaqueItem>(), isNotEmpty);
    });

    test('сброс: карты летят волной в сбросы владельцев, не дольше секунды, и ряды освобождаются', () {
      final game = round();
      final script = build(
        game,
        roundEvents(game.mineScore, game.theirScore),
        summaryOf(mine: game.mineScore, theirs: game.theirScore),
      );
      final flights = script.beats.whereType<FlightBeat>().where((beat) => beat.to is DiscardPlace).toList();
      expect(flights, hasLength(4));
      final first = flights.map((beat) => beat.start).reduce((a, b) => a < b ? a : b);
      final last = flights.map((beat) => beat.end).reduce((a, b) => a > b ? a : b);
      expect(last - first, lessThanOrEqualTo(StageTokens.discardTotal));
      expect(flights.where((beat) => beat.to == const DiscardPlace(mine: false)), hasLength(1));
      // Пока карта летит, на месте её нет, а соседи не съезжают.
      final mid = script.frameAt((first + last) / 2).rows[mineMelee]!.cards;
      expect(mid.length, 2);
      expect(mid.any((card) => card.hidden), isTrue);
    });

    test('Чудовища: оставшийся отряд остаётся в ряду и пульсирует золотом', () {
      final kept = cards.unit(Row.melee);
      final gone = cards.unit(Row.melee);
      final closing = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          rows: {
            Row.melee: rowOf([kept, gone], cards),
          },
          score: cards.strength(kept) + cards.strength(gone),
        ),
      );
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          rows: {
            Row.melee: rowOf([kept], cards),
          },
          discard: [gone],
          score: cards.strength(kept),
        ),
        round: 2,
      );
      final script = StageScriptBuilder(prev: closing, next: next, catalog: content.catalog).buildRound(
        1,
        [
          const Passed(Seat.one, auto: false),
          const RoundEnded(RoundResult(round: 1, scores: {Seat.one: 9, Seat.two: 1}, winner: Seat.one)),
          UnitKept(Seat.one, Row.melee, kept),
          const RoundStarted(2, Seat.two),
          const TurnStarted(Seat.two),
        ],
        summary: summaryOf(),
      )!;
      final end = script.frameAt(script.duration).rows[mineMelee]!.cards;
      expect(end.map((card) => card.view.card), [kept]);
      var pulsed = false;
      for (final time in times(script)) {
        pulsed |= script
            .frameAt(time)
            .items
            .whereType<GlowItem>()
            .any(
              (glow) => glow.place is RowCardPlace && (glow.place as RowCardPlace).card == kept.id,
            );
      }
      expect(pulsed, isTrue);
      expect(
        script.frameAt(script.duration).counters[(kind: StageCounter.rowScore, mine: true, row: Row.melee)]!.to,
        cards.strength(kept),
      );
    });

    test('Скеллиге: после ухода карт две карты возвращаются из сброса с подписью', () {
      final a = cards.unit(Row.melee);
      final b = cards.unit(Row.ranged);
      final closing = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          rows: {
            Row.melee: rowOf([a], cards),
            Row.ranged: rowOf([b], cards),
          },
        ),
        round: 2,
      );
      final next = viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          rows: {
            Row.melee: rowOf([a], cards),
            Row.ranged: rowOf([b], cards),
          },
        ),
        round: 3,
      );
      final script = StageScriptBuilder(prev: closing, next: next, catalog: content.catalog).buildRound(
        1,
        [
          const Passed(Seat.one, auto: false),
          const RoundEnded(RoundResult(round: 2, scores: {Seat.one: 4, Seat.two: 2}, winner: Seat.one)),
          UnitPlaced(Seat.one, Row.melee, a, EntrySource.perk),
          UnitPlaced(Seat.one, Row.ranged, b, EntrySource.perk),
          const RoundStarted(3, Seat.two),
          const TurnStarted(Seat.two),
        ],
        summary: summaryOf(),
      )!;
      var caption = false;
      var maxBack = 0;
      for (final time in times(script)) {
        final frame = script.frameAt(time);
        caption |= frame.items.whereType<CaptionItem>().any((item) => item.kind == CaptionKind.perkReturn);
        maxBack = frame.items.whereType<CardFlightItem>().where((item) => item.to is RowCardPlace).length > maxBack
            ? frame.items.whereType<CardFlightItem>().where((item) => item.to is RowCardPlace).length
            : maxBack;
      }
      expect(caption, isTrue);
      expect(maxBack, greaterThan(0));
      final end = script.frameAt(script.duration);
      expect(end.rows[mineMelee]!.cards.single.view.card, a);
      expect(end.rows[(mine: true, row: Row.ranged)]!.cards.single.view.card, b);
    });

    test('«Уменьшить движение»: карты не летят, полоса не дрожит, плашка не масштабируется', () {
      final game = round();
      final script = build(
        game,
        roundEvents(game.mineScore, game.theirScore),
        summaryOf(mine: game.mineScore, theirs: game.theirScore),
        style: const StageStyle(reduceMotion: true),
      );
      for (final time in times(script)) {
        final frame = script.frameAt(time);
        expect(frame.items.whereType<CardFlightItem>(), isEmpty, reason: '$time');
        expect(frame.shakes, isEmpty, reason: '$time');
        for (final plaque in frame.items.whereType<PlaqueItem>()) {
          expect(plaque.scaleY, 1);
        }
      }
      expect(script.frameAt(script.duration).rows[mineMelee]!.cards, isEmpty);
    });

    test('быстрая скорость укорачивает показ, порядок шагов сохраняется', () {
      final game = round();
      final events = roundEvents(game.mineScore, game.theirScore);
      final summary = summaryOf(mine: game.mineScore, theirs: game.theirScore);
      final normal = build(game, events, summary);
      final fast = build(game, events, summary, style: const StageStyle(scale: StageTokens.fastFactor));
      expect(fast.duration, lessThan(normal.duration * 0.7));
      expect(fast.steps.length, normal.steps.length);
    });

    test('«Пропустить» ведёт к началу следующего шага и, в конце, к концу сценария', () {
      final game = round();
      final script = build(
        game,
        roundEvents(game.mineScore, game.theirScore),
        summaryOf(mine: game.mineScore, theirs: game.theirScore),
      );
      expect(script.steps, orderedEquals([...script.steps]..sort()));
      expect(script.nextStep(0), script.steps[1]);
      expect(script.nextStep(script.steps.last + 1), script.duration);
    });
  });

  group('конец матча', () {
    ({PlayerView closing, PlayerView next, List<CardInstance> mine, CardInstance theirs, int mineScore, int theirScore})
    finished() {
      final game = round();
      final next = viewOf(
        cards,
        me: game.closing.me,
        opponent: sideOf(
          cards,
          Seat.two,
          handCount: 5,
          rows: {
            Row.melee: rowOf([game.theirs], cards),
          },
          score: game.theirScore,
          crystals: 0,
        ),
        phase: MatchPhase.finished,
        history: const [
          RoundResult(round: 1, scores: {Seat.one: 20, Seat.two: 5}, winner: Seat.one),
          RoundResult(round: 2, scores: {Seat.one: 12, Seat.two: 3}, winner: Seat.one),
        ],
        outcome: const MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals),
      );
      return (
        closing: game.closing,
        next: next,
        mine: game.mine,
        theirs: game.theirs,
        mineScore: game.mineScore,
        theirScore: game.theirScore,
      );
    }

    List<GameEvent> events(int mine, int theirs) => [
      const Passed(Seat.one, auto: false),
      RoundEnded(RoundResult(round: 3, scores: {Seat.one: mine, Seat.two: theirs}, winner: Seat.one)),
      const MatchEnded(MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals)),
    ];

    test('счёт держится 1,5 с, затем плашка «Победа» и потеря последнего камня, поле остаётся как было', () {
      final game = finished();
      final script = build(game, events(game.mineScore, game.theirScore), summaryOf(mine: game.mineScore));
      final held = script.frameAt(2400).items.whereType<CountItem>().single;
      expect(held.mine.to, game.mineScore);
      final banner = script.frameAt(3000).items.whereType<MatchBannerItem>().single;
      expect(banner.outcome, RoundOutcome.win);
      expect(banner.roundsMine, 2);
      expect(banner.roundsTheirs, 0);
      expect(banner.winner, Seat.one);
      expect(script.frameAt(3200).gems[false]!.remaining, 0);
      expect(script.frameAt(script.duration).gems[false]!.progress, 1);
      expect(script.beats.whereType<FlightBeat>(), isEmpty, reason: 'карты остаются на поле: сброса нет');
      for (final time in times(script)) {
        expect(script.frameAt(time).rows[mineMelee]?.cards.length ?? 2, 2);
      }
    });

    test('плашка исхода не пропускается тапом', () {
      final game = finished();
      final script = build(game, events(game.mineScore, game.theirScore), summaryOf(mine: game.mineScore));
      expect(script.tapSpeedsUp(3000), isFalse);
    });
  });

  group('звуки конца раунда и матча', () {
    test('выигранный раунд звучит победой в момент плашки, проигранный и ничья — поражением', () {
      final game = round();
      final expected = {
        RoundOutcome.win: SoundEffect.roundWon,
        RoundOutcome.loss: SoundEffect.roundLost,
        RoundOutcome.draw: SoundEffect.roundLost,
      };
      for (final MapEntry(key: outcome, value: effect) in expected.entries) {
        final script = build(game, roundEvents(game.mineScore, game.theirScore), summaryOf(outcome: outcome));
        expect(script.cues.map((cue) => cue.effect), [effect], reason: outcome.name);
        expect(script.cues.single.at, script.steps[1] + 1400, reason: 'плашка после подсчёта рядов');
      }
    });

    test('матч: победа и поражение звучат в момент плашки исхода', () {
      for (final (winner, effect) in [(Seat.one, SoundEffect.matchWon), (Seat.two, SoundEffect.matchLost)]) {
        final game = round();
        final next = viewOf(
          cards,
          me: game.closing.me,
          opponent: game.closing.opponent,
          phase: MatchPhase.finished,
          outcome: MatchOutcome(winner: winner, reason: MatchEndReason.crystals),
        );
        final script = StageScriptBuilder(prev: game.closing, next: next, catalog: content.catalog).buildRound(
          1,
          [
            const Passed(Seat.one, auto: false),
            RoundEnded(
              RoundResult(round: 3, scores: {Seat.one: game.mineScore, Seat.two: game.theirScore}, winner: winner),
            ),
            MatchEnded(MatchOutcome(winner: winner, reason: MatchEndReason.crystals)),
          ],
          summary: summaryOf(),
        )!;
        expect(script.cues.map((cue) => cue.effect), [effect]);
      }
    });
  });

  group('сдача и выход соперника', () {
    PlayerView resigned() => viewOf(
      cards,
      me: sideOf(cards, Seat.one, hand: [cards.unit(Row.melee)]),
      opponent: sideOf(cards, Seat.two, handCount: 5),
      phase: MatchPhase.finished,
      outcome: const MatchOutcome(winner: Seat.one, reason: MatchEndReason.resignation),
    );

    StageScript? scene(PlayerView view, List<GameEvent> events) =>
        StageScriptBuilder(prev: view, next: view, catalog: content.catalog).buildResignation(1, events);

    test('плашка исхода сразу, без подсчёта; у сдавшегося гаснет один из оставшихся камней', () {
      final view = resigned();
      final script = scene(view, const [
        MatchEnded(MatchOutcome(winner: Seat.one, reason: MatchEndReason.resignation)),
      ])!;
      final banner = script.frameAt(300).items.whereType<MatchBannerItem>().single;
      expect(banner.outcome, RoundOutcome.win);
      expect(banner.winner, Seat.one);
      expect(script.frameAt(script.duration).gems.keys, [false]);
      expect(script.frameAt(500).gems[false]!.remaining, 1);
      expect(script.beats.whereType<FlightBeat>(), isEmpty);
      expect(script.tapSpeedsUp(300), isFalse);
    });

    test('сдался я: плашка «Поражение», гаснет мой камень', () {
      final view = resigned();
      final script = scene(view, const [
        MatchEnded(MatchOutcome(winner: Seat.two, reason: MatchEndReason.resignation)),
      ])!;
      expect(script.frameAt(300).items.whereType<MatchBannerItem>().single.outcome, RoundOutcome.loss);
      expect(script.frameAt(script.duration).gems.keys, [true]);
    });

    test('партия кончилась не сдачей: сцены нет', () {
      expect(
        scene(resigned(), const [MatchEnded(MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals))]),
        isNull,
      );
    });
  });
}
