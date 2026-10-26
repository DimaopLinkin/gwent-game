import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/tutorial/application/mark_first_match_passed.dart';
import 'package:gwent/src/features/tutorial/domain/scenario_beat.dart';
import 'package:gwent/src/features/tutorial/domain/scenario_director.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_move.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_step.dart';
import 'package:gwent/src/features/tutorial/presentation/tutorial_cubit.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart' show RecordedMove;

import '../../../support/fakes.dart';

void main() {
  late InMemorySettingsRepository settings;
  late ScenarioDirector director;
  late TutorialCubit cubit;

  setUp(() {
    settings = InMemorySettingsRepository();
    director = ScenarioDirector(const [
      ShowBeat(TutorialStep.goal, []),
      PlayerBeat(PassMove(), step: TutorialStep.finalPass),
    ]);
    cubit = TutorialCubit(director, markPassed: MarkFirstMatchPassed(settings));
    addTearDown(cubit.close);
  });

  test('начинает с текущего звена, «Дальше» двигает сценарий и сбрасывает свёрнутость', () async {
    expect(cubit.state.beat, isA<ShowBeat>());

    cubit.toggleCollapsed();
    expect(cubit.state.collapsed, isTrue);
    cubit.toggleCollapsed();
    expect(cubit.state.collapsed, isFalse);

    cubit
      ..toggleCollapsed()
      ..acknowledge();
    await pumpEventQueue();
    expect(cubit.state.beat, isA<PlayerBeat>());
    expect(cubit.state.collapsed, isFalse, reason: 'новое звено показывается развёрнутым');
  });

  test('напоминание включается один раз и уходит со сменой звена', () async {
    cubit.nudge();
    await pumpEventQueue();
    expect(cubit.state.nudged, isTrue);

    cubit.acknowledge();
    await pumpEventQueue();
    expect(cubit.state.nudged, isFalse);
  });

  test('напоминание раскрывает свёрнутую подсказку, даже если уже включалось', () async {
    cubit
      ..toggleCollapsed()
      ..nudge();
    await pumpEventQueue();
    expect(cubit.state.collapsed, isFalse);
    expect(cubit.state.nudged, isTrue);

    cubit.toggleCollapsed();
    expect(cubit.state.collapsed, isTrue);
    cubit.nudge();
    await pumpEventQueue();
    expect(cubit.state.collapsed, isFalse, reason: 'ход мимо окон снова показывает подсказку');
  });

  test('обучение отмечается пройденным, когда сценарий дошёл до конца, и не раньше', () async {
    cubit.acknowledge();
    await pumpEventQueue();
    expect(settings.saved.firstMatchPassed, isFalse);

    director.journal.append(const RecordedMove(Seat.one, Pass()));
    await pumpEventQueue();
    expect(cubit.state.beat, isNull);
    expect(settings.saved, const AppSettings(firstMatchPassed: true));
  });

  test('флаг не записался: ошибка уходит наблюдателю, держатель живёт', () async {
    final errors = <Object>[];
    final observer = Bloc.observer;
    Bloc.observer = _RecordingObserver(errors);
    addTearDown(() => Bloc.observer = observer);
    final failingDirector = ScenarioDirector(const [PlayerBeat(PassMove())]);
    final failing = TutorialCubit(failingDirector, markPassed: MarkFirstMatchPassed(_FailingSettings()));
    addTearDown(failing.close);

    failingDirector.journal.append(const RecordedMove(Seat.one, Pass()));
    await pumpEventQueue();

    expect(errors, [isA<StateError>()]);
    expect(failing.isClosed, isFalse);
    expect(failing.state.beat, isNull);
  });
}

base class _FailingSettings extends InMemorySettingsRepository {
  @override
  Future<void> save(AppSettings settings) async => throw StateError('нет места');
}

class _RecordingObserver extends BlocObserver {
  _RecordingObserver(this.errors);

  final List<Object> errors;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    errors.add(error);
  }
}
