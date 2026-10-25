import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/replay/application/load_replay.dart';
import 'package:gwent/src/features/replay/presentation/replay_cubit.dart';
import 'package:gwent/src/features/replay/presentation/replay_state.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../support/replay_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayedMatch match;
  const gap = Duration(milliseconds: 100);

  setUpAll(() async => match = await playRecordedMatch());

  /// Держатель с загруженным реплеем; поле «ещё занято», пока тест не сообщит обратное.
  Future<ReplayCubit> opened(WidgetTester tester, {String? recordId}) async {
    // Загрузка идёт по-настоящему (набор карт читается из ассетов), поэтому держатель создаётся вне часов теста;
    // шаги показа ниже уже идут по часам теста.
    final cubit = (await tester.runAsync(() async {
      final cubit = ReplayCubit(LoadReplay(match.history, match.loader), recordId ?? match.record.id, stepGap: gap);
      await cubit.stream.firstWhere((state) => state is! ReplayLoading);
      return cubit;
    }))!;
    addTearDown(cubit.close);
    return cubit;
  }

  ReplayShowing showing(ReplayCubit cubit) => cubit.state as ReplayShowing;

  testWidgets('реплей открывается на первом шаге и идёт сам, поле сбрасывается', (tester) async {
    final cubit = await opened(tester);

    final state = showing(cubit);
    expect(state.index, 0);
    expect(state.playing, isTrue);
    expect(state.reset, isTrue);
    expect(state.animate, isTrue);
    expect(state.seat, Seat.one);
    expect(state.speed, ReplaySpeed.normal);
    expect(state.steps.first.view.phase, MatchPhase.playing);
    expect(state.steps.last.view.phase, MatchPhase.finished);
  });

  testWidgets('нет партии или реплея: показать нечего', (tester) async {
    final cubit = await opened(tester, recordId: 'нет такой');

    expect(cubit.state, isA<ReplayFailed>().having((state) => state.failure, 'failure', ReplayFailure.missing));
  });

  testWidgets('следующий шаг выходит после паузы, когда поле закончило показ, и не раньше', (tester) async {
    final cubit = await opened(tester);
    cubit.fieldReported(busy: true);
    await tester.pump(gap * 10);
    expect(showing(cubit).index, 0, reason: 'поле занято: автопоказ ждёт');

    cubit.fieldReported(busy: false);
    await tester.pump(gap - const Duration(milliseconds: 1));
    expect(showing(cubit).index, 0);
    await tester.pump(const Duration(milliseconds: 1));

    final state = showing(cubit);
    expect(state.index, 1);
    expect(state.animate, isTrue);
    expect(state.reset, isFalse);
    expect(state.revision, 2);
    expect(state.playing, isTrue);
    // Пока поле не доложило о новом шаге, следующий не выходит.
    await tester.pump(gap * 10);
    expect(showing(cubit).index, 1);
  });

  testWidgets('скорость сокращает и растягивает паузу между шагами', (tester) async {
    final cubit = await opened(tester);
    cubit.setSpeed(ReplaySpeed.fastest);
    cubit.fieldReported(busy: false);
    await tester.pump(gap ~/ 4);
    expect(showing(cubit).index, 1);

    cubit.setSpeed(ReplaySpeed.half);
    cubit.fieldReported(busy: false);
    await tester.pump(gap);
    expect(showing(cubit).index, 1);
    await tester.pump(gap);
    expect(showing(cubit).index, 2);
  });

  testWidgets('пауза останавливает показ, пуск продолжает', (tester) async {
    final cubit = await opened(tester);
    cubit.fieldReported(busy: false);
    cubit.togglePlay();
    expect(showing(cubit).playing, isFalse);
    await tester.pump(gap * 10);
    expect(showing(cubit).index, 0);

    cubit.togglePlay();
    expect(showing(cubit).playing, isTrue);
    await tester.pump(gap);
    expect(showing(cubit).index, 1);
  });

  testWidgets('шаг вперёд вручную: пока поле занято, не принимается; иначе ставит на паузу', (tester) async {
    final cubit = await opened(tester);

    cubit.next();
    expect(showing(cubit).index, 0);

    cubit.fieldReported(busy: false);
    cubit.next();
    final state = showing(cubit);
    expect(state.index, 1);
    expect(state.playing, isFalse);
    expect(state.animate, isTrue);
  });

  testWidgets('шаг назад ставит поле в прежнее состояние без анимаций и на паузу', (tester) async {
    final cubit = await opened(tester);
    cubit.fieldReported(busy: false);
    cubit.next();
    cubit.fieldReported(busy: false);
    cubit.next();

    cubit.previous();

    final state = showing(cubit);
    expect(state.index, 1);
    expect(state.reset, isTrue);
    expect(state.animate, isFalse);
    expect(state.playing, isFalse);
    cubit.previous();
    cubit.previous();
    expect(showing(cubit).index, 0, reason: 'дальше начала не уйти');
  });

  testWidgets('раунды: вперёд к началу следующего, назад к началу текущего, затем предыдущего', (tester) async {
    final cubit = await opened(tester);
    final steps = showing(cubit).steps;
    final rounds = steps.map((step) => step.round).toSet().toList()..sort();
    expect(rounds.length, greaterThan(1), reason: 'в партии больше одного раунда');
    int startOf(int round) => steps.indexWhere((step) => step.round == round);

    cubit.nextRound();
    expect(showing(cubit).index, startOf(rounds[1]));
    expect(showing(cubit).reset, isTrue);
    expect(showing(cubit).animate, isFalse);

    cubit.next();
    cubit.fieldReported(busy: false);
    cubit.next();
    if (steps[startOf(rounds[1]) + 2].round == rounds[1]) {
      cubit.previousRound();
      expect(showing(cubit).index, startOf(rounds[1]), reason: 'с середины раунда — к его началу');
    }

    cubit.previousRound();
    expect(showing(cubit).index, startOf(rounds[0]));

    for (var i = 0; i < rounds.length; i++) {
      cubit.nextRound();
    }
    expect(showing(cubit).index, steps.length - 1, reason: 'в последнем раунде — к последнему шагу');
  });

  testWidgets('на последнем шаге показ останавливается, пуск начинает реплей сначала', (tester) async {
    final cubit = await opened(tester);
    final last = showing(cubit).steps.length - 1;
    for (var i = 0; i < last; i++) {
      cubit.fieldReported(busy: false);
      await tester.pump(gap);
    }
    expect(showing(cubit).index, last);
    cubit.fieldReported(busy: false);
    expect(showing(cubit).playing, isFalse);

    cubit.togglePlay();
    final state = showing(cubit);
    expect((state.index, state.playing, state.reset, state.animate), (0, true, true, true));
  });

  testWidgets('смена места сохраняет ход партии и сбрасывает поле', (tester) async {
    final cubit = await opened(tester);
    for (var i = 0; i < 8; i++) {
      cubit.fieldReported(busy: false);
      cubit.next();
    }
    final frame = showing(cubit).step.frame;

    cubit.setSeat(Seat.two);

    final state = showing(cubit);
    expect(state.seat, Seat.two);
    expect(state.step.view.viewer, Seat.two);
    expect(state.step.frame, lessThanOrEqualTo(frame));
    expect(state.steps.where((step) => step.frame > state.step.frame).first.frame, greaterThan(frame));
    expect(state.reset, isTrue);
    expect(state.animate, isFalse);
    cubit.setSeat(Seat.two);
    expect(showing(cubit).revision, state.revision, reason: 'то же место — ничего не меняется');
  });

  testWidgets('закрытый держатель не заводит таймеров и не падает от поздних отчётов поля', (tester) async {
    final cubit = await opened(tester);
    await tester.runAsync(cubit.close);

    cubit.fieldReported(busy: false);
    await tester.pump(gap * 10);
    expect(tester.takeException(), isNull);
  });
}
