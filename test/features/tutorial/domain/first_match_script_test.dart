import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/tutorial/application/start_first_match.dart';
import 'package:gwent/src/features/tutorial/domain/first_match_script.dart';
import 'package:gwent/src/features/tutorial/domain/scenario_beat.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../support/tutorial_intents.dart';

/// Проходит сценарий «Первой партии» на настоящем пакете карт и настоящем движке так, как это делает игрок: показы
/// подтверждаются, ходы игрока идут через стол, бот ходит сам. Если случайность движка или данные карт изменились,
/// тест падает здесь, а не в руках игрока.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FirstMatchStarted> start() async {
    final result = await StartFirstMatch(
      LoadGameContent(AssetContentSource.basePack(rootBundle)),
      botThinkTime: Duration.zero,
    )(playerDeckName: 'Первая партия', opponentDeckName: 'Скеллиге');
    return result as FirstMatchStarted;
  }

  test('игрок ходит первым, колоды проходят правила, пересдачи нет', () async {
    final started = await start();
    final views = <PlayerView>[];
    final subscription = started.session.table.updates.listen((update) {
      if (update is ViewsChanged) views.add(update.views[Seat.one]!);
    });
    await pumpEventQueue();
    expect(views, isNotEmpty);
    final first = views.first;
    expect(first.phase, MatchPhase.playing);
    expect(first.turn, Seat.one);
    expect(first.me.handCount, 10);
    await subscription.cancel();
    await started.session.table.close();
  });

  test('сценарий проходится до победы 2:0 со счётом второго раунда 23:5', () async {
    final started = await start();
    final table = started.session.table;
    final director = started.director;
    PlayerView? view;
    final failures = <Object>[];
    final rounds = <RoundResult>[];
    final subscription = table.updates.listen((update) {
      switch (update) {
        case ViewsChanged(:final views, :final events):
          view = views[Seat.one];
          rounds.addAll(events[Seat.one]!.whereType<RoundEnded>().map((event) => event.result));
        case TableFailed(:final error):
          failures.add(error);
        case IntentRefused() || TableRematchChanged() || TableRematchAgreed():
          failures.add(update);
      }
    });
    await pumpEventQueue();

    Future<void> untilBeatChanges(int from) async {
      for (var i = 0; i < 200 && director.index == from && failures.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    while (!director.isCompleted && failures.isEmpty) {
      final index = director.index;
      switch (director.current!) {
        case ShowBeat():
          director.acknowledge(director.current!);
        case PlayerBeat(:final move):
          table.submit(Seat.one, intentFor(view!, move));
          await untilBeatChanges(index);
        case BotBeat():
          await untilBeatChanges(index);
      }
      expect(director.index, greaterThan(index), reason: 'сценарий встал на звене $index: ${director.beats[index]}');
    }
    await pumpEventQueue();

    expect(failures, isEmpty);
    expect(view!.phase, MatchPhase.finished);
    expect(view!.outcome!.winner, Seat.one);
    expect(rounds.map((round) => round.winner), [Seat.one, Seat.one]);
    expect((rounds.first.scores[Seat.one], rounds.first.scores[Seat.two]), (16, 14));
    expect((rounds.last.scores[Seat.one], rounds.last.scores[Seat.two]), FirstMatchScript.finalScore);
    await subscription.cancel();
    await table.close();
  });

  test('стол не пускает ход, которого сценарий не ждёт', () async {
    final started = await start();
    final table = started.session.table;
    PlayerView? view;
    final subscription = table.updates.listen((update) {
      if (update is ViewsChanged) view = update.views[Seat.one];
    });
    await pumpEventQueue();
    var nudges = 0;
    final nudged = started.director.nudges.listen((_) => nudges++);
    // Первое звено — показ: никакой ход не проходит, пока игрок не нажал «Дальше».
    table.submit(Seat.one, const Pass());
    table.submit(Seat.one, PlayCard(view!.me.hand!.first.id, row: Row.melee));
    await pumpEventQueue();
    expect(nudges, 2);
    expect(started.director.index, 0);
    expect(view!.me.handCount, 10);
    expect(view!.me.passed, isFalse);
    await nudged.cancel();
    await subscription.cancel();
    await table.close();
  });
}
