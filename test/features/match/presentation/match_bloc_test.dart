import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' as history;
import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Deck;

import '../../../support/fakes.dart';
import '../../../support/match_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late InMemoryMatchHistoryRepository matches;
  late MatchBloc bloc;

  setUpAll(() async => content = await loadBaseContent());

  MatchBloc newBloc({
    DeckRepository? decks,
    int seed = 3,
    MatchHistoryRepository? history,
    BotFactory createBot = GreedyBot.new,
    bool awaitingSession = false,
  }) {
    final bloc = MatchBloc(
      StartMatch(
        LoadGameContent(AssetContentSource.basePack(rootBundle)),
        decks ??
            InMemoryDeckRepository([
              realDeck(content, Faction.skellige, id: 'skellige'),
              realDeck(content, Faction.monsters, id: 'monsters'),
            ]),
        FixedSeedGenerator(seed),
        createBot: createBot,
        botThinkTime: Duration.zero,
      ),
      RecordFinishedMatch(
        RecordMatch(history ?? matches, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator()),
      ),
      awaitingSession: awaitingSession,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  setUp(() {
    matches = InMemoryMatchHistoryRepository();
    bloc = newBloc();
  });

  test('против бота: от колод до итога и записи в историю', () async {
    final states = <MatchScreenState>[];
    final finished = _playOut(bloc, states);
    bloc.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    final result = await finished;

    expect(states.first, isA<MatchStarting>());
    expect(states[1], isA<MatchIntro>(), reason: 'партия начинается со знакомства, пока на экране нет рук');
    expect(states.whereType<MatchHandover>(), isEmpty, reason: 'против бота телефон никому не передаётся');
    final inProgress = states.whereType<MatchInProgress>().toList();
    expect(inProgress.first.view.phase, MatchPhase.redraw);
    expect(inProgress.first.events, isNotEmpty, reason: 'раздача приходит событиями');
    expect(inProgress.map((state) => state.view.viewer).toSet(), {Seat.one});
    // Игрок пасует в каждом раунде, поэтому бот выигрывает партию.
    expect(result.outcome.winner, Seat.two);
    expect(matches.records.single.mode, history.MatchMode.ai);
    expect(matches.records.single.outcome, history.MatchOutcome.defeat);
    expect(result.record, matches.records.single);

    // Прежде чем открыть итог матча, партия показывает поле с последним ходом и счётом.
    final firstFinished = states.indexWhere((state) => state is MatchFinished);
    expect(
      states[firstFinished - 1],
      isA<MatchInProgress>()
          .having((state) => state.view.phase, 'phase', MatchPhase.finished)
          .having((state) => state.events.whereType<MatchEnded>(), 'MatchEnded', isNotEmpty),
    );
  });

  test('hot-seat: телефон переходит к тому, кто должен действовать, события копятся для каждого места', () async {
    final states = <MatchScreenState>[];
    final finished = _playOut(bloc, states);
    bloc.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.hotSeat, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    await finished;

    // Начало партии: знакомство без рук, потом руку первого игрока видит только он.
    expect(states[1], isA<MatchIntro>());
    final firstHandover = states.indexWhere((state) => state is MatchHandover);
    expect(
      states[firstHandover],
      isA<MatchHandover>()
          .having((state) => state.next, 'next', Seat.one)
          .having((state) => state.kind, 'kind', HandoverKind.redraw),
    );
    final redrawOne = states[firstHandover + 1] as MatchInProgress;
    expect((redrawOne.view.viewer, redrawOne.view.phase), (Seat.one, MatchPhase.redraw));
    // Первый закончил пересдачу: телефон уходит второму, и тот видит раздачу и пересдачу первого.
    expect(states[firstHandover + 2], isA<MatchHandover>().having((state) => state.next, 'next', Seat.two));
    final redrawTwo = states[firstHandover + 3] as MatchInProgress;
    expect(redrawTwo.view.viewer, Seat.two);
    expect(redrawTwo.events, contains(const RedrawFinished(Seat.one)));
    expect(states.last, isA<MatchFinished>());
    expect(matches.records.single.mode, history.MatchMode.hotSeat);
  });

  test('hot-seat: сдача, пока передача телефона ждёт конца показа, доходит до партии', () async {
    final states = <MatchScreenState>[];
    final finished = _playOut(bloc, states, resignAtRoundEndHandover: true);
    bloc.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.hotSeat, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    final result = await finished;
    expect(result.outcome.reason, MatchEndReason.resignation);
  });

  group('поле раунда для показа конца раунда', () {
    Future<List<MatchScreenState>> playOut(LocalMatchMode mode) async {
      final states = <MatchScreenState>[];
      final finished = _playOut(bloc, states);
      bloc.add(MatchStartRequested(LocalMatchRequest(mode: mode, deckOne: 'skellige', deckTwo: 'monsters')));
      await finished;
      return states;
    }

    test('против бота: поле приходит только с обновлением, в котором раунд закончился', () async {
      final states = await playOut(LocalMatchMode.vsBot);
      final progress = states.whereType<MatchInProgress>().toList();
      final ending = progress.where((state) => state.events.any((event) => event is RoundEnded)).toList();
      expect(ending, isNotEmpty);
      for (final state in ending) {
        final closing = state.closing;
        expect(closing, isNotNull, reason: 'конец раунда показывают по полю перед ним');
        expect(closing!.round, state.view.round - (state.view.phase == MatchPhase.finished ? 0 : 1));
        expect(closing.viewer, state.view.viewer);
      }
      expect(
        progress.where((state) => state.events.every((event) => event is! RoundEnded)).every((s) => s.closing == null),
        isTrue,
        reason: 'остальные обновления поля раунда не несут',
      );
    });

    test('hot-seat: у каждого места своё поле раунда, чужое не подставляется', () async {
      final states = await playOut(LocalMatchMode.hotSeat);
      final ending = states
          .whereType<MatchInProgress>()
          .where((state) => state.events.any((event) => event is RoundEnded))
          .toList();
      expect(ending, isNotEmpty);
      for (final state in ending) {
        if (state.closing case final closing?) expect(closing.viewer, state.view.viewer);
      }
    });

    test('hot-seat: конец раунда видит тот, у кого телефон, передача идёт после него и без повтора', () async {
      final states = await playOut(LocalMatchMode.hotSeat);
      var handedAfterRoundEnd = 0;
      for (var i = 0; i < states.length - 1; i++) {
        final state = states[i];
        if (state is! MatchInProgress || state.view.phase != MatchPhase.playing) continue;
        if (!state.events.any((event) => event is RoundEnded)) continue;
        final following = states[i + 1];
        if (following is! MatchHandover) continue;
        handedAfterRoundEnd++;
        expect(state.closing, isNotNull, reason: 'у того, кто кончил раунд, конец раунда с полем перед ним');
        expect(state.closing!.viewer, state.view.viewer);
        expect(following.next, state.view.viewer.opponent, reason: 'телефон уходит другому');
        final received = states.skip(i + 2).whereType<MatchInProgress>().first;
        expect(received.view.viewer, following.next);
        expect(
          received.events.any((event) => event is RoundEnded),
          isFalse,
          reason: 'второй игрок конец не пересматривает',
        );
        expect(received.closing, isNull);
        final ended = state.events.whereType<RoundEnded>().last.result.round;
        expect(
          states.skip(i + 1).whereType<MatchInProgress>().takeWhile((s) => s.view.round == state.view.round + 1),
          everyElement(
            isA<MatchInProgress>().having(
              (s) => s.events.whereType<RoundEnded>().any((e) => e.result.round == ended),
              'повтор конца раунда $ended',
              isFalse,
            ),
          ),
          reason: 'ни одно место не пересматривает конец раунда, который уже показан',
        );
        expect(received.events.whereType<RoundStarted>(), isNotEmpty, reason: 'новый раунд ему остаётся');
      }
      expect(handedAfterRoundEnd, greaterThan(0), reason: 'в партии есть раунд, после которого ходит другой игрок');
    });
  });

  /// Виды передач телефона в партии вдвоём с заданным сидом (сид решает, кто ходит первым).
  Future<List<HandoverKind>> handoverKinds(int seed) async {
    final hotSeat = newBloc(seed: seed);
    final states = <MatchScreenState>[];
    final finished = _playOut(hotSeat, states);
    hotSeat.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.hotSeat, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    await finished;
    return [for (final state in states.whereType<MatchHandover>()) state.kind];
  }

  test('hot-seat: если первым ходит не тот, кто держит телефон, передача называется «первый ход»', () async {
    final kinds = await handoverKinds(4);
    expect(kinds.take(2), [HandoverKind.redraw, HandoverKind.redraw], reason: 'каждый игрок пересдаёт свои карты');
    expect(kinds[2], HandoverKind.firstMove);
    expect(kinds.skip(3), everyElement(HandoverKind.turn));
  });

  test('hot-seat: если первым ходит тот, у кого телефон, первой передачи хода нет, дальше передачи — ходы', () async {
    final kinds = await handoverKinds(3);
    expect(kinds.take(2), [HandoverKind.redraw, HandoverKind.redraw]);
    expect(kinds.skip(2), isNotEmpty);
    expect(kinds.skip(2), everyElement(HandoverKind.turn));
  });

  test('знакомство называет фракции, лидеров и колоды обоих игроков', () async {
    final intro = bloc.stream.firstWhere((state) => state is MatchIntro);
    bloc.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    final roster = (await intro as MatchIntro).roster;
    expect(roster.hotSeat, isFalse);
    expect(roster.isLocal(Seat.one), isTrue);
    expect(roster.isLocal(Seat.two), isFalse);
    expect(roster.player(Seat.one).faction, Faction.skellige);
    expect(roster.player(Seat.two).faction, Faction.monsters);
    expect(roster.player(Seat.one).deckName, 'skellige');
    expect(roster.player(Seat.two).deckName, 'monsters');
  });

  test('знакомство ждёт: пока игрок не нажал или не вышло время, поле не показывается', () async {
    final states = <MatchScreenState>[];
    final subscription = bloc.stream.listen(states.add);
    addTearDown(subscription.cancel);
    bloc.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    await bloc.stream.firstWhere((state) => state is MatchIntro);
    await pumpEventQueue();
    expect(states.last, isA<MatchIntro>());
    expect(states.whereType<MatchInProgress>(), isEmpty);

    bloc.add(const MatchIntroFinished());
    await bloc.stream.firstWhere((state) => state is! MatchIntro);
    expect(bloc.state, anyOf(isA<MatchToss>(), isA<MatchInProgress>()));
  });

  test('«знакомство» и «жребий» вне своего места игнорируются', () async {
    bloc.add(const MatchIntroFinished());
    bloc.add(const MatchTossFinished());
    bloc.add(const MatchHandoverAccepted());
    bloc.add(const MatchRematchRequested());
    await pumpEventQueue();
    expect(bloc.state, isA<MatchIdle>());
  });

  test('жребий: после знакомства экран называет, кто ходит первым, и только потом показывает пересдачу', () async {
    final table = _FakeTable();
    final states = <MatchScreenState>[];
    final subscription = bloc.stream.listen(states.add);
    addTearDown(subscription.cancel);

    bloc.add(MatchSessionOpened(_session(table, content)));
    await pumpEventQueue();
    table.push(
      ViewsChanged(
        {Seat.one: _startView(content)},
        const {
          Seat.one: [FirstPlayerChosen(Seat.two, byChoice: true)],
        },
      ),
    );
    await pumpEventQueue();
    expect(states, [isA<MatchIntro>()]);

    bloc.add(const MatchIntroFinished());
    await pumpEventQueue();
    expect(
      states.last,
      isA<MatchToss>()
          .having((state) => state.first, 'first', Seat.two)
          .having((state) => state.byChoice, 'byChoice', true),
    );

    bloc.add(const MatchTossFinished());
    await pumpEventQueue();
    expect(states.last, isA<MatchInProgress>().having((state) => state.view.phase, 'phase', MatchPhase.redraw));
  });

  test('сдача: Resign на любом этапе заканчивает партию поражением и записывает её', () async {
    final states = <MatchScreenState>[];
    final subscription = bloc.stream.listen((state) {
      states.add(state);
      if (state is MatchIntro) bloc.add(const MatchIntroFinished());
      if (state is MatchToss) bloc.add(const MatchTossFinished());
      if (state is MatchInProgress && state.view.phase == MatchPhase.redraw && state.refusal == null) {
        bloc.add(const MatchIntentSubmitted(Resign()));
      }
    });
    addTearDown(subscription.cancel);
    bloc.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    final finished = await bloc.stream.firstWhere((state) => state is MatchFinished && state.record != null);
    expect((finished as MatchFinished).outcome.winner, Seat.two);
    expect(matches.records.single.outcome, history.MatchOutcome.defeat);
    expect(
      states.whereType<MatchInProgress>().any((state) => state.view.phase == MatchPhase.finished),
      isFalse,
      reason: 'после сдачи поле с последним ходом не держат',
    );
  });

  test('реванш: та же партия с теми же колодами начинается заново со знакомства', () async {
    final first = <MatchScreenState>[];
    final firstResult = await (() {
      final finished = _playOut(bloc, first);
      bloc.add(
        const MatchStartRequested(
          LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
        ),
      );
      return finished;
    })();
    expect(firstResult.canRematch, isTrue);

    final second = <MatchScreenState>[];
    final secondFinished = _playOut(bloc, second);
    bloc.add(const MatchRematchRequested());
    final secondResult = await secondFinished;
    expect(second.first, isA<MatchStarting>());
    expect(second[1], isA<MatchIntro>());
    expect(second.whereType<MatchInProgress>().first.view.phase, MatchPhase.redraw);
    expect(secondResult.record, isNotNull);
    expect(matches.records, hasLength(2));
  });

  test('реванш до конца записи в историю: итог прежней партии не затирает новую', () async {
    final gate = Completer<void>();
    final slow = newBloc(history: _GatedHistory(gate.future));
    final finished = _playOut(slow, <MatchScreenState>[], recorded: false);
    slow.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    await finished;

    slow.add(const MatchRematchRequested());
    await pumpEventQueue();
    expect(slow.state, isA<MatchIntro>());
    gate.complete();
    await pumpEventQueue();
    expect(slow.state, isA<MatchIntro>(), reason: 'запись прежней партии закончилась, но экран остался на новой');
  });

  test('двойное нажатие «Реванш» открывает один стол', () async {
    var bots = 0;
    final counted = newBloc(
      createBot: (engine, catalog) {
        bots++;
        return GreedyBot(engine, catalog);
      },
    );
    final finished = _playOut(counted, <MatchScreenState>[]);
    counted.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    await finished;
    expect(bots, 1);

    counted
      ..add(const MatchRematchRequested())
      ..add(const MatchRematchRequested());
    await pumpEventQueue();
    expect(bots, 2);
    expect(counted.state, isA<MatchIntro>());
  });

  test('партия, открытая снаружи, реванша не предлагает: запроса колод у неё нет', () async {
    final table = _FakeTable();
    bloc.add(MatchSessionOpened(_session(table, content)));
    await pumpEventQueue();
    table.push(ViewsChanged({Seat.one: _startView(content)}, const {Seat.one: []}));
    await pumpEventQueue();
    bloc.add(const MatchIntroFinished());
    await pumpEventQueue();
    bloc.add(const MatchRematchRequested());
    await pumpEventQueue();
    expect(bloc.state, isA<MatchInProgress>());
  });

  test(
    'сетевая партия: держатель ждёт стол, а открытый стол ведёт к знакомству; второй стол не принимается и закрывается',
    () async {
      final waiting = newBloc(awaitingSession: true);
      expect(waiting.state, isA<MatchStarting>());
      final table = _FakeTable();
      final other = _FakeTable();

      waiting.add(MatchSessionOpened(_session(table, content)));
      await pumpEventQueue();
      table.push(ViewsChanged({Seat.one: _startView(content)}, const {Seat.one: []}));
      await waiting.stream.firstWhere((state) => state is MatchIntro);

      waiting.add(MatchSessionOpened(_session(other, content)));
      await pumpEventQueue();
      expect(waiting.state, isA<MatchIntro>());
      expect(other.closed, isTrue, reason: 'второй стол закрывается, чтобы сетевая игра не осталась висеть');
      expect(table.closed, isFalse);
    },
  );

  test('отказ движка показывается тому, кто держит телефон', () async {
    final refused = Completer<MatchInProgress>();
    final subscription = bloc.stream.listen((state) {
      if (state is MatchIntro) bloc.add(const MatchIntroFinished());
      if (state is MatchToss) bloc.add(const MatchTossFinished());
      if (state is MatchInProgress && state.refusal != null) refused.complete(state);
      if (state is MatchInProgress && state.refusal == null && state.view.phase == MatchPhase.redraw) {
        // Пас во время пересдачи движок отклоняет.
        bloc.add(const MatchIntentSubmitted(Pass()));
      }
    });
    addTearDown(subscription.cancel);
    bloc.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    final state = await refused.future;
    expect(state.refusal!.reason, RejectReason.wrongPhase);
    expect(state.events, isEmpty);
  });

  test('партию не начать: состояние с причиной', () async {
    final failed = bloc.stream.firstWhere((state) => state is MatchStartFailed);
    bloc.add(
      const MatchStartRequested(LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'gone')),
    );
    expect((await failed as MatchStartFailed).reason, isA<MatchDeckNotFound>());
  });

  for (final (one, two, seed) in [
    (Faction.skellige, Faction.monsters, 1),
    (Faction.scoiatael, Faction.nilfgaard, 2),
    (Faction.northernRealms, Faction.scoiatael, 4),
  ]) {
    test('hot-seat с разыгрыванием карт: руку видит только тот, кто взял телефон (${one.name}, ${two.name})', () async {
      final hotSeat = newBloc(
        decks: InMemoryDeckRepository([realDeck(content, one, id: 'one'), realDeck(content, two, id: 'two')]),
        seed: seed,
      );
      final states = <MatchScreenState>[];
      // Нарушение (рука не того, кто держит телефон) _playOut превращает в ошибку.
      final finished = _playOut(hotSeat, states, playCards: true);
      hotSeat.add(
        const MatchStartRequested(LocalMatchRequest(mode: LocalMatchMode.hotSeat, deckOne: 'one', deckTwo: 'two')),
      );
      final result = await finished;
      expect(result.view.history, isNotEmpty);
      expect(states.whereType<MatchHandover>().length, greaterThan(2));
    });
  }

  test('сбой стола: экран ошибки остаётся, стол закрыт', () async {
    final table = _FakeTable();
    final states = <MatchScreenState>[];
    final subscription = bloc.stream.listen(states.add);
    addTearDown(subscription.cancel);

    bloc.add(MatchSessionOpened(_session(table, content)));
    await pumpEventQueue();
    table.push(ViewsChanged({Seat.one: _startView(content)}, const {Seat.one: []}));
    await pumpEventQueue();
    bloc.add(const MatchIntroFinished());
    await pumpEventQueue();
    table.push(TableFailed(StateError('бот сломался')));
    table.push(ViewsChanged({Seat.one: _startView(content)}, const {Seat.one: []}));
    await pumpEventQueue();

    expect(states, [isA<MatchIntro>(), isA<MatchInProgress>(), isA<MatchCrashed>()]);
    expect(table.closed, isTrue);
    bloc.add(const MatchIntentSubmitted(FinishRedraw()));
    await pumpEventQueue();
    expect(table.submitted, isEmpty);
  });

  test('держатель закрыли во время старта: стол закрывается, бот не ходит', () async {
    final gate = Completer<void>();
    var botAsked = 0;
    final starting = newBloc(
      decks: _GatedDecks(gate.future, [
        realDeck(content, Faction.skellige, id: 'skellige'),
        realDeck(content, Faction.monsters, id: 'monsters'),
      ]),
      createBot: (engine, catalog) => _CountingBot(GreedyBot(engine, catalog), () => botAsked++),
    );
    starting.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    await starting.stream.firstWhere((state) => state is MatchStarting);
    final closed = starting.close();
    gate.complete();
    await closed;
    await pumpEventQueue();
    // Стол спросил бота один раз при раздаче и закрылся, не дав ему ходить дальше.
    expect(botAsked, 1);
  });

  test('сбой хранилища при старте: экран ошибки, а не вечная загрузка', () async {
    // Ошибка помечена обработанной заранее: колоды спросят только после загрузки контента.
    final failing = newBloc(decks: _GatedDecks(Future.error(StateError('база недоступна'))..ignore(), const []));
    final crashed = failing.stream.firstWhere((state) => state is MatchCrashed);
    failing.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    expect((await crashed as MatchCrashed).error, isA<StateError>());
  });

  test('ошибка записи в историю не убирает итог с экрана', () async {
    final errors = <Object>[];
    final observer = Bloc.observer;
    Bloc.observer = _ErrorObserver(errors);
    addTearDown(() => Bloc.observer = observer);
    final failing = newBloc(history: _FailingHistory());
    final states = <MatchScreenState>[];
    final finished = _playOut(failing, states, recorded: false);
    failing.add(
      const MatchStartRequested(
        LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
      ),
    );
    final result = await finished;
    await pumpEventQueue();
    expect(result.record, isNull);
    expect(failing.state, same(result), reason: 'итог остаётся на экране');
    expect(errors.single, isA<StateError>());
  });
}

/// Играет партию за людей: берёт телефон при передаче, заканчивает пересдачу, в выборе берёт первый вариант,
/// в свой ход пасует (с [playCards] сначала разыгрывает карты, пока в руке больше четырёх). Возвращает итог,
/// когда он записан в историю (без [recorded] — как только он на экране).
///
/// Как человек, действует один раз на каждое решение: пока бот пересдаёт, экран обновляется, а игрок своё
/// действие уже отправил. Проверяет главное правило hot-seat: экран показывает руку только того, кто взял телефон
/// при последней передаче.
Future<MatchFinished> _playOut(
  MatchBloc bloc,
  List<MatchScreenState> states, {
  bool playCards = false,
  bool recorded = true,
  bool resignAtRoundEndHandover = false,
}) {
  final finished = Completer<MatchFinished>();
  Object? decided;
  Seat? holder;
  void fail(Object error) {
    if (!finished.isCompleted) finished.completeError(error);
  }

  late final StreamSubscription<MatchScreenState> subscription;
  subscription = bloc.stream.listen((state) {
    states.add(state);
    if (state case MatchInProgress(:final view) || MatchFinished(:final view)) {
      if (holder != null && view.viewer != holder) fail(StateError('рука ${view.viewer} на экране у $holder'));
    }
    switch (state) {
      case MatchIntro():
        bloc.add(const MatchIntroFinished());
      case MatchToss():
        bloc.add(const MatchTossFinished());
      case MatchHandover(:final next):
        if (resignAtRoundEndHandover && states.length > 1 && _endsRound(states[states.length - 2])) {
          // Телефон ещё у того, кто кончил раунд: он сдаётся, не дожидаясь передачи.
          bloc.add(const MatchIntentSubmitted(Resign()));
          return;
        }
        holder = next;
        bloc.add(const MatchHandoverAccepted());
      case MatchInProgress(refusal: _?) when playCards:
        // Карта требует цели, которую простой игрок не выбирает: пасует.
        bloc.add(const MatchIntentSubmitted(Pass()));
      case MatchInProgress(:final refusal?):
        fail(StateError('движок отклонил действие: ${refusal.reason}'));
      case MatchInProgress(:final view) when state.awaitsMe:
        final decision = (view.viewer, view.phase, view.round, view.turn, view.me, view.choice);
        if (decision == decided) return;
        decided = decision;
        bloc.add(MatchIntentSubmitted(_humanIntent(view, playCards: playCards)));
      case MatchFinished(record: _?):
        if (!finished.isCompleted) finished.complete(state);
      case MatchFinished() when !recorded:
        if (!finished.isCompleted) finished.complete(state);
      case MatchCrashed(:final error):
        fail(error);
      case MatchStartFailed(:final reason):
        fail(StateError('партия не начата: $reason'));
      case MatchIdle() || MatchStarting() || MatchInProgress() || MatchFinished():
    }
  });
  return finished.future.whenComplete(subscription.cancel);
}

bool _endsRound(MatchScreenState state) =>
    state is MatchInProgress && state.view.phase == MatchPhase.playing && state.events.any((e) => e is RoundEnded);

Intent _humanIntent(PlayerView view, {required bool playCards}) {
  if (view.choice case final choice?) return ChooseOption(choice.options.first);
  if (view.phase == MatchPhase.redraw) return const FinishRedraw();
  if (playCards && view.me.handCount > 4 && view.me.playable.isNotEmpty) return PlayCard(view.me.playable.first);
  return const Pass();
}

/// Начатая партия против бота на поддельном столе.
MatchSession _session(MatchTable table, GameContent content) => MatchSession(
  mode: history.MatchMode.ai,
  table: table,
  content: content,
  factionIds: const {Seat.one: 'skellige', Seat.two: 'monsters'},
);

/// Проекция первого места сразу после раздачи.
PlayerView _startView(GameContent content) {
  final engine = GwentEngine(content.catalog, rules: content.rules);
  final start =
      engine.start(
            MatchSetup(
              one: realDeck(content, Faction.skellige, id: 'one').toEngineDeck(),
              two: realDeck(content, Faction.monsters, id: 'two').toEngineDeck(),
              rng: const SeededRng(7),
            ),
          )
          as Accepted;
  return engine.project(start.state, Seat.one);
}

/// Стол, обновления которого присылает тест.
final class _FakeTable implements MatchTable {
  final StreamController<TableUpdate> _updates = StreamController();
  final List<Intent> submitted = [];
  bool closed = false;

  void push(TableUpdate update) => _updates.add(update);

  @override
  Set<Seat> get localSeats => const {Seat.one};

  @override
  Stream<TableUpdate> get updates => _updates.stream;

  @override
  void submit(Seat seat, Intent intent) => submitted.add(intent);

  @override
  Future<void> close() async => closed = true;
}

/// Колоды, которые отдаются, только когда завершится [gate].
final class _GatedDecks implements DeckRepository {
  _GatedDecks(this._gate, List<Deck> decks) : _decks = InMemoryDeckRepository(decks);

  final Future<void> _gate;
  final InMemoryDeckRepository _decks;

  @override
  Stream<List<Deck>> watchAll() => _decks.watchAll();

  @override
  Future<Deck?> findById(String id) async {
    await _gate;
    return _decks.findById(id);
  }

  @override
  Future<List<Deck>> findByFaction(String factionId) => _decks.findByFaction(factionId);

  @override
  Future<void> save(Deck deck, {bool activate = false}) => _decks.save(deck, activate: activate);

  @override
  Future<void> delete(String id) => _decks.delete(id);

  @override
  Stream<Map<String, String>> watchActiveDeckIds() => _decks.watchActiveDeckIds();

  @override
  Future<String?> findActiveDeckId(String factionId) => _decks.findActiveDeckId(factionId);

  @override
  Future<void> setActive(String deckId) => _decks.setActive(deckId);
}

/// Бот, который сообщает о каждом вопросе.
final class _CountingBot implements MatchBot {
  _CountingBot(this._bot, this._onAsked);

  final MatchBot _bot;
  final void Function() _onAsked;

  @override
  Intent? decide(MatchState state, Seat seat) {
    _onAsked();
    return _bot.decide(state, seat);
  }
}

/// История, в которую нельзя записать.
final class _FailingHistory implements MatchHistoryRepository {
  @override
  Stream<List<history.MatchRecord>> watchAll() => const Stream.empty();

  @override
  Future<void> add(history.MatchRecord record) => Future.error(StateError('диск полон'));
}

/// История, которая записывает партию, когда откроют [gate].
final class _GatedHistory implements MatchHistoryRepository {
  _GatedHistory(this._gate);

  final Future<void> _gate;

  @override
  Stream<List<history.MatchRecord>> watchAll() => const Stream.empty();

  @override
  Future<void> add(history.MatchRecord record) => _gate;
}

/// Наблюдатель, который собирает ошибки держателей состояния.
final class _ErrorObserver extends BlocObserver {
  _ErrorObserver(this._errors);

  final List<Object> _errors;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}
