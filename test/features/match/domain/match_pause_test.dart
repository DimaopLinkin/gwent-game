import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/match/domain/match_pause.dart';

void main() {
  const tick = Duration(milliseconds: 50);

  testWidgets('delay без паузы ждёт заданное время', (tester) async {
    final pause = MatchPause();
    var done = false;
    unawaited(pause.delay(const Duration(milliseconds: 700)).then((_) => done = true));

    await tester.pump(const Duration(milliseconds: 650));
    expect(done, isFalse);
    await tester.pump(tick);
    expect(done, isTrue);
  });

  testWidgets('время на паузе в delay не считается: отсчёт встаёт и продолжается с того же места', (tester) async {
    final pause = MatchPause();
    var done = false;
    unawaited(pause.delay(const Duration(milliseconds: 700)).then((_) => done = true));

    await tester.pump(const Duration(milliseconds: 300));
    pause.setPaused(paused: true);
    expect(pause.isPaused, isTrue);
    await tester.pump(const Duration(seconds: 30));
    expect(done, isFalse);

    pause.setPaused(paused: false);
    expect(pause.isPaused, isFalse);
    await tester.pump(const Duration(milliseconds: 350));
    expect(done, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(done, isTrue);
  });

  testWidgets('delay, начатый на паузе, ждёт её конца', (tester) async {
    final pause = MatchPause()..setPaused(paused: true);
    var done = false;
    unawaited(pause.delay(const Duration(milliseconds: 100)).then((_) => done = true));

    await tester.pump(const Duration(seconds: 10));
    expect(done, isFalse);
    pause.setPaused(paused: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(done, isTrue);
  });

  testWidgets('untilResumed без паузы завершается сразу, на паузе ждёт; повторное включение ничего не меняет', (
    tester,
  ) async {
    final pause = MatchPause();
    var immediate = false;
    unawaited(pause.untilResumed().then((_) => immediate = true));
    await tester.pump();
    expect(immediate, isTrue);

    pause
      ..setPaused(paused: true)
      ..setPaused(paused: true);
    var resumed = false;
    unawaited(pause.untilResumed().then((_) => resumed = true));
    await tester.pump();
    expect(resumed, isFalse);
    pause.setPaused(paused: false);
    await tester.pump();
    expect(resumed, isTrue);
  });
}
