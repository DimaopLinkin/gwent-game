import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' as history;
import 'package:gwent_engine/gwent_engine.dart';

import '../../../support/fakes.dart';
import '../../../support/match_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late InMemoryMatchHistoryRepository matches;
  late MatchBloc bloc;

  setUpAll(() async => content = await loadBaseContent());

  setUp(() {
    final decks = InMemoryDeckRepository([
      realDeck(content, Faction.skellige, id: 'skellige'),
      realDeck(content, Faction.monsters, id: 'monsters'),
    ]);
    matches = InMemoryMatchHistoryRepository();
    bloc = MatchBloc(
      StartMatch(
        LoadGameContent(AssetContentSource.basePack(rootBundle)),
        decks,
        FixedSeedGenerator(3),
        botThinkTime: Duration.zero,
      ),
      RecordFinishedMatch(RecordMatch(matches, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator())),
    );
    addTearDown(bloc.close);
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
    // Экран с рукой показывается только тому, кто держит телефон, и только после передачи.
    for (final (index, state) in states.indexed) {
      if (state is! MatchInProgress || index == 0) continue;
      final before = states[index - 1];
      if (before is MatchHandover) expect(state.view.viewer, before.next);
    }
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
}

/// Играет партию за людей: берёт телефон при передаче, заканчивает пересдачу, в выборе берёт первый вариант,
/// в свой ход пасует. Возвращает итог, когда он записан в историю.
///
/// Как человек, действует один раз на каждое решение: пока бот пересдаёт, экран обновляется, а игрок своё
/// действие уже отправил.
Future<MatchFinished> _playOut(MatchBloc bloc, List<MatchScreenState> states) {
  final finished = Completer<MatchFinished>();
  Object? decided;
  late final StreamSubscription<MatchScreenState> subscription;
  subscription = bloc.stream.listen((state) {
    states.add(state);
    switch (state) {
      case MatchHandover():
        bloc.add(const MatchHandoverAccepted());
      case MatchInProgress(:final refusal?):
        finished.completeError(StateError('движок отклонил действие: ${refusal.reason}'));
      case MatchInProgress(:final view) when state.awaitsMe:
        final decision = (view.viewer, view.phase, view.round, view.me, view.choice);
        if (decision == decided) return;
        decided = decision;
        bloc.add(MatchIntentSubmitted(_humanIntent(view)));
      case MatchFinished(record: _?):
        finished.complete(state);
      case MatchCrashed(:final error):
        finished.completeError(error);
      case MatchStartFailed(:final reason):
        finished.completeError(StateError('партия не начата: $reason'));
      case MatchIdle() || MatchStarting() || MatchInProgress() || MatchFinished():
    }
  });
  return finished.future.whenComplete(subscription.cancel);
}

Intent _humanIntent(PlayerView view) {
  if (view.choice case final choice?) return ChooseOption(choice.options.first);
  return view.phase == MatchPhase.redraw ? const FinishRedraw() : const Pass();
}
