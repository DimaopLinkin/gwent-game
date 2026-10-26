import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/tutorial/domain/first_match_script.dart';
import 'package:gwent/src/features/tutorial/domain/scenario_beat.dart';
import 'package:gwent/src/features/tutorial/domain/scenario_director.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_move.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_step.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart' show RecordedMove;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MatchState state;

  setUpAll(() async {
    // Состояние партии нужно режиссёру только как аргумент: берём настоящее начало «Первой партии».
    final content = switch (await LoadGameContent(AssetContentSource.basePack(rootBundle))()) {
      GameContentReady(:final content) => content,
      final other => fail('набор карт не загрузился: $other'),
    };
    final started = GwentEngine(content.catalog, rules: content.rules).start(
      MatchSetup(
        one: FirstMatchScript.playerDeck.toEngineDeck(),
        two: FirstMatchScript.opponentDeck.toEngineDeck(),
        rng: const SeededRng(FirstMatchScript.seed),
      ),
    );
    state = switch (started) {
      Accepted(:final state) => state,
      Rejected() => fail('партия не началась'),
    };
  });

  RecordedMove move(Seat seat) => RecordedMove(seat, const Pass());

  ScenarioDirector newDirector() => ScenarioDirector(const [
    ShowBeat(TutorialStep.goal, []),
    PlayerBeat(PassMove(), step: TutorialStep.finalPass),
    BotBeat(PassMove()),
  ]);

  test('«Дальше» двигает только показ', () {
    final director = newDirector();
    director.acknowledge();
    expect(director.index, 1);
    director.acknowledge();
    expect(director.index, 1, reason: 'на ходе игрока «Дальше» ничего не делает');
  });

  test('принятый ход нужного места двигает звено, чужого — нет', () {
    final director = newDirector()..acknowledge();

    director.journal.append(move(Seat.two));
    expect(director.index, 1, reason: 'ход бота, когда ждут игрока');
    director.journal.append(move(Seat.one));
    expect(director.index, 2);
    director.journal.append(move(Seat.one));
    expect(director.index, 2, reason: 'ход игрока, когда ждут бота');
    director.journal.append(move(Seat.two));
    expect(director.isCompleted, isTrue);
    expect(director.current, isNull);
  });

  test('ход вне сценария не проходит и вызывает напоминание', () async {
    final director = newDirector();
    var nudges = 0;
    director.nudges.listen((_) => nudges++);

    expect(director.allows(state, Seat.one, const Pass()), isFalse, reason: 'ждут «Дальше»');
    director.acknowledge();
    expect(director.allows(state, Seat.two, const Pass()), isFalse, reason: 'ходит не тот');
    expect(director.allows(state, Seat.one, const UseLeader()), isFalse, reason: 'ждут пас');
    expect(director.allows(state, Seat.one, const Pass()), isTrue);
    await pumpEventQueue();
    expect(nudges, 3, reason: 'напоминание на каждый отказ, на разрешённый ход нет');
  });

  test('бот ждёт своего звена и закрытие его отпускает', () async {
    final director = newDirector();
    final waiting = director.botIntent(state, Seat.two);
    var done = false;
    unawaited(waiting.whenComplete(() => done = true));
    await pumpEventQueue();
    expect(done, isFalse, reason: 'звено бота ещё не наступило');

    director.acknowledge();
    director.journal.append(move(Seat.one));
    expect(await waiting, isA<Pass>());

    final other = newDirector();
    final pending = other.botIntent(state, Seat.two);
    other.close();
    expect(await pending, isNull);
  });
}
