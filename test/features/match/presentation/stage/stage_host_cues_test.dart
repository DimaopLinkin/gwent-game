import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_host.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_script.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';

void main() {
  const script = StageScript(
    id: 1,
    beats: [],
    rows: {},
    duration: 2000,
    steps: [0, 1000],
    cues: [
      SoundCue(at: 0, effect: SoundEffect.draw),
      SoundCue(at: 400, effect: SoundEffect.horn),
      SoundCue(at: 800, effect: SoundEffect.frost),
      SoundCue(at: 1000, effect: SoundEffect.roundWon),
      SoundCue(at: 1500, effect: SoundEffect.pass),
    ],
  );

  late List<SoundEffect> played;
  late VoidCallback skip;

  Future<void> pumpHost(WidgetTester tester, {StageScript? script = script}) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: StageHost(
        script: script,
        onDone: (_) {},
        onCue: played.add,
        builder: (context, frame, speedUp, skipStep) {
          skip = skipStep;
          return const SizedBox();
        },
      ),
    ),
  );

  setUp(() => played = []);

  testWidgets('звуки играют, когда время сценария доходит до их момента, каждый один раз', (tester) async {
    await pumpHost(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(played, [SoundEffect.draw]);

    await tester.pump(const Duration(milliseconds: 400));
    expect(played, [SoundEffect.draw, SoundEffect.horn]);

    await tester.pump(const Duration(milliseconds: 600));
    expect(played, [SoundEffect.draw, SoundEffect.horn, SoundEffect.frost, SoundEffect.roundWon]);

    await tester.pump(const Duration(seconds: 3));
    expect(played, hasLength(5));
    expect(played.last, SoundEffect.pass);
  });

  testWidgets('«Пропустить» не играет звуки, оставшиеся за перескоком, но играет звук начала шага', (tester) async {
    await pumpHost(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(played, [SoundEffect.draw]);

    skip();
    await tester.pump(const Duration(milliseconds: 16));
    expect(played, [SoundEffect.draw, SoundEffect.roundWon], reason: 'горн и мороз пропущены, плашка шага звучит');
  });

  testWidgets('новый сценарий играет свои звуки с начала', (tester) async {
    await pumpHost(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(played, [SoundEffect.draw, SoundEffect.horn]);

    const next = StageScript(
      id: 2,
      beats: [],
      rows: {},
      duration: 1000,
      cues: [SoundCue(at: 0, effect: SoundEffect.scorch)],
    );
    await pumpHost(tester, script: next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(played.last, SoundEffect.scorch);
  });

  testWidgets('без обработчика и без сценария ничего не падает', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StageHost(script: script, onDone: (_) {}, builder: (_, _, _, _) => const SizedBox()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await pumpHost(tester, script: null);
    expect(played, isEmpty);
  });
}
