import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/match/domain/local_match_table.dart';
import 'package:gwent/src/features/match/domain/match_pause.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match/domain/seat_agent.dart';
import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart' show InMemoryMatchJournal, MatchRecord, RecordedMove, Ruleset;

import '../../../support/match_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late GwentEngine engine;
  late Accepted start;

  setUpAll(() async {
    content = await loadBaseContent();
    engine = GwentEngine(content.catalog, rules: content.rules);
    start =
        engine.start(
              MatchSetup(
                one: realDeck(content, Faction.skellige, id: 'one').toEngineDeck(),
                two: realDeck(content, Faction.monsters, id: 'two').toEngineDeck(),
                rng: const SeededRng(42),
              ),
            )
            as Accepted;
  });

  LocalMatchTable table({Map<Seat, SeatAgent> agents = const {}}) {
    final table = LocalMatchTable(engine: engine, state: start.state, startEvents: start.events, agents: agents);
    addTearDown(table.close);
    return table;
  }

  test('hot-seat: оба места здешние, первым приходит раздача обоим вместе', () async {
    final hotSeat = table();
    expect(hotSeat.localSeats, Seat.values.toSet());
    final first = await hotSeat.updates.first as ViewsChanged;
    expect(first.views.keys, Seat.values);
    expect(first.views[Seat.one]!.phase, MatchPhase.redraw);
    expect(first.views[Seat.one]!.me.hand, isNotEmpty);
    expect(first.events[Seat.one], engine.eventsFor(start.events, Seat.one));
  });

  test('принятое намерение даёт новые проекции, отклонённое — IntentRefused без изменений', () async {
    final hotSeat = table();
    final updates = StreamIterator(hotSeat.updates);
    await updates.moveNext();

    hotSeat.submit(Seat.one, const Pass());
    await updates.moveNext();
    expect(
      updates.current,
      isA<IntentRefused>()
          .having((update) => update.seat, 'seat', Seat.one)
          .having((update) => update.reject.reason, 'reason', RejectReason.wrongPhase),
    );
    expect(hotSeat.state, start.state);

    hotSeat.submit(Seat.one, const FinishRedraw());
    await updates.moveNext();
    final changed = updates.current as ViewsChanged;
    expect(changed.views[Seat.one]!.me.redrawDone, isTrue);
    expect(changed.events[Seat.one], contains(const RedrawFinished(Seat.one)));
  });

  group('журнал', () {
    InMemoryMatchJournal journal() => InMemoryMatchJournal()
      ..begin(
        MatchRecord(
          matchId: 'm',
          ruleset: const Ruleset(id: 'pack', hash: 'hash', engineVersion: engineVersion),
          seed: 42,
          one: realDeck(content, Faction.skellige, id: 'one').toEngineDeck(),
          two: realDeck(content, Faction.monsters, id: 'two').toEngineDeck(),
        ),
      );

    test('принятые намерения людей попадают в журнал по порядку, отклонённые нет', () async {
      final log = journal();
      final hotSeat = LocalMatchTable(
        engine: engine,
        state: start.state,
        startEvents: start.events,
        journal: log,
      );
      addTearDown(hotSeat.close);
      final updates = StreamIterator(hotSeat.updates);
      await updates.moveNext();

      hotSeat.submit(Seat.one, const Pass());
      await updates.moveNext();
      hotSeat.submit(Seat.one, const FinishRedraw());
      await updates.moveNext();
      hotSeat.submit(Seat.two, const FinishRedraw());
      await updates.moveNext();

      expect(log.record!.moves, const [
        RecordedMove(Seat.one, FinishRedraw()),
        RecordedMove(Seat.two, FinishRedraw()),
      ]);
    });

    test('полная партия с ботом: журнал содержит ходы обоих и проигрывается в то же состояние', () async {
      final log = journal();
      final human = GreedyBot(engine, content.catalog);
      final vsBot = LocalMatchTable(
        engine: engine,
        state: start.state,
        startEvents: start.events,
        agents: {Seat.two: BotAgent(GreedyBot(engine, content.catalog), thinkTime: Duration.zero)},
        journal: log,
      );
      addTearDown(vsBot.close);
      final finished = Completer<void>();
      vsBot.updates.listen((update) {
        switch (update) {
          case ViewsChanged(:final views):
            if (views[Seat.one]!.outcome != null) {
              finished.complete();
            } else if (human.decide(vsBot.state, Seat.one) case final intent?) {
              vsBot.submit(Seat.one, intent);
            }
          case IntentRefused(:final reject):
            finished.completeError(StateError('отказ ${reject.reason}'));
          case TableFailed(:final error):
            finished.completeError(error);
          case TableRematchChanged() || TableRematchAgreed():
            break;
        }
      });
      await finished.future;

      final moves = log.record!.moves;
      expect(moves.map((move) => move.seat).toSet(), Seat.values.toSet());
      expect(log.record!.replay(engine), vsBot.state);
    });
  });

  test('за место агента и после закрытия ходить нельзя', () async {
    final vsAgent = table(agents: {Seat.two: _ScriptedAgent()});
    expect(vsAgent.localSeats, {Seat.one});
    expect(() => vsAgent.submit(Seat.two, const FinishRedraw()), throwsArgumentError);
    await vsAgent.close();
    expect(() => vsAgent.submit(Seat.one, const FinishRedraw()), throwsStateError);
  });

  test('без человека стол не создаётся', () {
    expect(
      () => LocalMatchTable(
        engine: engine,
        state: start.state,
        startEvents: start.events,
        agents: {for (final seat in Seat.values) seat: _ScriptedAgent()},
      ),
      throwsArgumentError,
    );
  });

  test('агент ходит после каждого изменения, пока ему есть что делать', () async {
    final vsAgent = table(
      agents: {
        Seat.two: _ScriptedAgent([const FinishRedraw()]),
      },
    );
    final changes = vsAgent.updates.where((update) => update is ViewsChanged).cast<ViewsChanged>();
    final views = await changes.take(2).toList();
    expect(views.last.views[Seat.one]!.opponent.redrawDone, isTrue);
  });

  test('решение агента по устаревшему состоянию отбрасывается, агент решает заново', () async {
    final agent = _GatedAgent();
    final vsAgent = table(agents: {Seat.two: agent});
    await pumpEventQueue();
    expect(agent.asked, 1);

    // Пока агент думает, человек заканчивает пересдачу: партия изменилась.
    vsAgent.submit(Seat.one, const FinishRedraw());
    agent.answer(const FinishRedraw());
    await pumpEventQueue();
    expect(agent.asked, 2, reason: 'первое решение относилось к старому состоянию');
    expect(vsAgent.state.player(Seat.two).redrawDone, isFalse);

    agent.answer(const FinishRedraw());
    await pumpEventQueue();
    expect(vsAgent.state.player(Seat.two).redrawDone, isTrue);
  });

  test('отклонённый ход агента и ошибка агента прерывают партию', () async {
    final rejected = table(
      agents: {
        Seat.two: _ScriptedAgent([const Pass()]),
      },
    );
    expect(await rejected.updates.firstWhere((update) => update is TableFailed), isA<TableFailed>());

    final throwing = table(agents: {Seat.two: _ThrowingAgent()});
    final failed = await throwing.updates.firstWhere((update) => update is TableFailed) as TableFailed;
    expect(failed.error, isA<StateError>());
  });

  test('агент молчит, когда партия ждёт его: партия прерывается, а не встаёт', () async {
    // При пересдаче партия ждёт обоих, а агент ничего не делает.
    final silent = table(agents: {Seat.two: _ScriptedAgent()});
    final failed = await silent.updates.firstWhere((update) => update is TableFailed) as TableFailed;
    expect(failed.error, isA<StateError>());
  });

  group('пауза', () {
    testWidgets('бот на паузе не думает и не ходит, после паузы доделывает оставшееся время', (tester) async {
      final pause = MatchPause();
      final vsBot = LocalMatchTable(
        engine: engine,
        state: start.state,
        startEvents: start.events,
        pause: pause,
        agents: {Seat.two: BotAgent(GreedyBot(engine, content.catalog), pause: pause)},
      );
      // Время идёт шагами: цепочку таймеров паузы одним большим pump тест не пройдёт.
      Future<void> elapse(int milliseconds) async {
        for (var passed = 0; passed < milliseconds; passed += 50) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await elapse(300);
      vsBot.setPaused(paused: true);
      await elapse(300000);
      expect(vsBot.state, start.state, reason: 'за время паузы бот не ходит');

      vsBot.setPaused(paused: false);
      await elapse(300);
      expect(vsBot.state, start.state, reason: 'от 700 мс думания осталось ещё 400');
      await elapse(200);
      expect(vsBot.state, isNot(start.state), reason: 'после паузы бот сделал свой первый ход');

      // Бот уже думает над следующим ходом: стол закрывается, и таймер доходит до конца.
      await vsBot.close();
      await elapse(1000);
    });

    test('решение, пришедшее на паузе, применяется только после неё', () async {
      final agent = _GatedAgent();
      final vsAgent = table(agents: {Seat.two: agent});
      await pumpEventQueue();

      vsAgent.setPaused(paused: true);
      agent.answer(const FinishRedraw());
      await pumpEventQueue();
      expect(vsAgent.state.player(Seat.two).redrawDone, isFalse);

      vsAgent.setPaused(paused: false);
      await pumpEventQueue();
      expect(vsAgent.state.player(Seat.two).redrawDone, isTrue);
    });

    test('закрытие стола на паузе отпускает ожидающего агента без хода', () async {
      final agent = _GatedAgent();
      final vsAgent = table(agents: {Seat.two: agent});
      await pumpEventQueue();
      vsAgent.setPaused(paused: true);
      agent.answer(const FinishRedraw());
      await pumpEventQueue();

      await vsAgent.close();
      await pumpEventQueue();
      expect(vsAgent.state.player(Seat.two).redrawDone, isFalse);
    });
  });

  test('полная партия: человек против жадного бота доходит до итога', () async {
    final human = GreedyBot(engine, content.catalog);
    final vsBot = table(agents: {Seat.two: BotAgent(GreedyBot(engine, content.catalog), thinkTime: Duration.zero)});
    final finished = Completer<PlayerView>();
    vsBot.updates.listen((update) {
      switch (update) {
        case ViewsChanged(:final views):
          final view = views[Seat.one]!;
          if (view.outcome != null) {
            finished.complete(view);
          } else if (human.decide(vsBot.state, Seat.one) case final intent?) {
            vsBot.submit(Seat.one, intent);
          }
        case IntentRefused(:final reject):
          finished.completeError(StateError('отказ ${reject.reason}'));
        case TableFailed(:final error):
          finished.completeError(error);
        case TableRematchChanged() || TableRematchAgreed():
          finished.completeError(StateError('в местной партии согласия на реванш нет'));
      }
    });
    final view = await finished.future;
    expect(view.phase, MatchPhase.finished);
    expect(view.history, isNotEmpty);
  });
}

/// Агент, который отдаёт намерения по списку, а потом молчит.
final class _ScriptedAgent implements SeatAgent {
  _ScriptedAgent([List<Intent> intents = const []]) : _intents = [...intents];

  final List<Intent> _intents;

  @override
  Future<Intent?> decide(MatchState state, Seat seat) async => _intents.isEmpty ? null : _intents.removeAt(0);
}

/// Агент, который отвечает, только когда тест скажет.
final class _GatedAgent implements SeatAgent {
  int asked = 0;
  Completer<Intent?>? _pending;

  void answer(Intent? intent) => _pending!.complete(intent);

  @override
  Future<Intent?> decide(MatchState state, Seat seat) {
    asked++;
    if (state.player(seat).redrawDone) return Future.value();
    return (_pending = Completer()).future;
  }
}

/// Агент с ошибкой внутри (как бот, у которого движок отклонил все варианты).
final class _ThrowingAgent implements SeatAgent {
  @override
  Future<Intent?> decide(MatchState state, Seat seat) async => throw StateError('бот сломался');
}
