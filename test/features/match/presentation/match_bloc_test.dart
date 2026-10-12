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

    // Начало партии: руку первого игрока видит только он.
    expect(states[1], isA<MatchHandover>().having((state) => state.next, 'next', Seat.one));
    final redrawOne = states[2] as MatchInProgress;
    expect((redrawOne.view.viewer, redrawOne.view.phase), (Seat.one, MatchPhase.redraw));
    // Первый закончил пересдачу: телефон уходит второму, и тот видит раздачу и пересдачу первого.
    expect(states[3], isA<MatchHandover>().having((state) => state.next, 'next', Seat.two));
    final redrawTwo = states[4] as MatchInProgress;
    expect(redrawTwo.view.viewer, Seat.two);
    expect(redrawTwo.events, contains(const RedrawFinished(Seat.one)));
    expect(states.last, isA<MatchFinished>());
    expect(matches.records.single.mode, history.MatchMode.hotSeat);
  });

  test('отказ движка показывается тому, кто держит телефон', () async {
    final refused = Completer<MatchInProgress>();
    final subscription = bloc.stream.listen((state) {
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
    table.push(TableFailed(StateError('бот сломался')));
    table.push(ViewsChanged({Seat.one: _startView(content)}, const {Seat.one: []}));
    await pumpEventQueue();

    expect(states, [isA<MatchInProgress>(), isA<MatchCrashed>()]);
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
      case MatchHandover(:final next):
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
