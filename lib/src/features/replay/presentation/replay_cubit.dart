import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/replay/application/load_replay.dart';
import 'package:gwent/src/features/replay/domain/replay_timeline.dart';
import 'package:gwent/src/features/replay/presentation/replay_state.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;

/// Держатель экрана реплея: загружает партию и ведёт показ по шагам.
///
/// Поле рисует экран (`FieldView` с `FieldCubit`), а этот держатель говорит, какой шаг на поле и что с ним делать:
/// показать анимациями или просто поставить. Автопоказ идёт так: когда поле закончило показ шага ([fieldReported]),
/// через паузу `stepGap` / скорость выходит следующий шаг. Ручные шаги вперёд, пока поле занято, не принимаются;
/// переход назад, к началу и по раундам идёт сразу и поле сбрасывает.
final class ReplayCubit extends Cubit<ReplayState> {
  /// Создаёт держатель и сразу загружает реплей партии [recordId]; [stepGap] — пауза между шагами на обычной скорости.
  ReplayCubit(this._load, this._recordId, {this.stepGap = const Duration(milliseconds: 700)})
    : super(const ReplayLoading()) {
    unawaited(_open());
  }

  final LoadReplay _load;
  final String _recordId;

  /// Пауза между шагами на обычной скорости.
  final Duration stepGap;

  Timer? _timer;

  /// Поле показывает шаг (или об этом ещё не сообщило): автопоказ ждёт.
  bool _busy = true;

  Future<void> _open() async {
    final LoadReplayResult result;
    try {
      result = await _load(_recordId);
    } on Object catch (error, stackTrace) {
      // Сбой хранилища или набора карт: повторять бесполезно, реплей недоступен.
      addError(error, stackTrace);
      if (!isClosed) emit(const ReplayFailed(ReplayFailure.corrupted));
      return;
    }
    if (isClosed) return;
    switch (result) {
      case ReplayLoaded(:final data):
        final seat = data.timeline.perspective;
        emit(
          ReplayShowing(
            data: data,
            seat: seat,
            steps: data.timeline.stepsFor(seat),
            index: 0,
            playing: true,
            speed: ReplaySpeed.normal,
            revision: 1,
            reset: true,
            animate: true,
          ),
        );
      case ReplayMissing():
        emit(const ReplayFailed(ReplayFailure.missing));
      case ReplayContentUnavailable():
        emit(const ReplayFailed(ReplayFailure.contentUnavailable));
      case ReplayUnavailable(:final reason):
        emit(
          ReplayFailed(switch (reason) {
            ReplayUnavailableReason.contentChanged => ReplayFailure.contentChanged,
            ReplayUnavailableReason.corrupted => ReplayFailure.corrupted,
          }),
        );
    }
  }

  /// Поле сообщает, занято ли оно показом текущего шага. Экран вызывает сразу после того, как вывел шаг на поле, и
  /// каждый раз, когда занятость поля меняется.
  void fieldReported({required bool busy}) {
    if (isClosed) return;
    _busy = busy;
    _schedule();
  }

  /// Пуск и пауза; на последнем шаге пуск начинает реплей сначала.
  void togglePlay() {
    final current = state;
    if (current is! ReplayShowing) return;
    if (current.playing) {
      _timer?.cancel();
      emit(current.copyWith(playing: false));
    } else if (current.atEnd) {
      _show(current, index: 0, playing: true, reset: true, animate: true);
    } else {
      emit(current.copyWith(playing: true));
      _schedule();
    }
  }

  /// Шаг вперёд. Пока поле показывает прошлый шаг, не принимается; ставит реплей на паузу.
  void next() {
    final current = state;
    if (current is! ReplayShowing || current.atEnd || _busy) return;
    _show(current, index: current.index + 1, playing: false, reset: false, animate: true);
  }

  /// Шаг назад: поле встаёт в состояние предыдущего шага без анимаций; ставит реплей на паузу.
  void previous() {
    final current = state;
    if (current is! ReplayShowing || current.atStart) return;
    _show(current, index: current.index - 1, playing: false, reset: true, animate: false);
  }

  /// К началу текущего раунда, а с его начала — к началу предыдущего.
  void previousRound() {
    final current = state;
    if (current is! ReplayShowing || current.atStart) return;
    final steps = current.steps;
    var start = current.index;
    while (start > 0 && steps[start - 1].round == steps[current.index].round) {
      start--;
    }
    final target = start < current.index ? start : _roundStart(steps, steps[start - 1].round);
    _show(current, index: target, playing: false, reset: true, animate: false);
  }

  /// К началу следующего раунда; в последнем раунде — к последнему шагу.
  void nextRound() {
    final current = state;
    if (current is! ReplayShowing || current.atEnd) return;
    final round = current.step.round;
    final target = current.steps.indexWhere((step) => step.round > round);
    _show(current, index: target < 0 ? current.steps.length - 1 : target, playing: false, reset: true, animate: false);
  }

  /// Меняет скорость; идущий показ продолжается на новой.
  void setSpeed(ReplaySpeed speed) {
    final current = state;
    if (current is! ReplayShowing || current.speed == speed) return;
    emit(current.copyWith(speed: speed));
    // Идущая пауза между шагами не начинается заново: частые нажатия не должны откладывать шаг.
    if (_timer?.isActive != true) _schedule();
  }

  /// Смотреть партию глазами места [seat]: реплей остаётся на том же ходе партии.
  void setSeat(Seat seat) {
    final current = state;
    if (current is! ReplayShowing || current.seat == seat || !current.data.timeline.seats.contains(seat)) return;
    final steps = current.data.timeline.stepsFor(seat);
    final frame = current.step.frame;
    final index = steps.lastIndexWhere((step) => step.frame <= frame);
    _show(
      current.copyWith(seat: seat, steps: steps),
      index: index < 0 ? 0 : index,
      playing: current.playing,
      reset: true,
      animate: false,
    );
  }

  static int _roundStart(List<ReplayStep> steps, int round) => steps.indexWhere((step) => step.round == round);

  void _show(
    ReplayShowing from, {
    required int index,
    required bool playing,
    required bool reset,
    required bool animate,
  }) {
    _timer?.cancel();
    // Что поле покажет, оно ещё не доложило: автопоказ ждёт его отчёта.
    _busy = true;
    emit(
      from.copyWith(index: index, playing: playing, revision: from.revision + 1, reset: reset, animate: animate),
    );
  }

  void _schedule() {
    _timer?.cancel();
    if (isClosed) return;
    final current = state;
    if (current is! ReplayShowing || !current.playing || _busy) return;
    if (current.atEnd) {
      emit(current.copyWith(playing: false));
      return;
    }
    _timer = Timer(stepGap * (1 / current.speed.factor), _advance);
  }

  void _advance() {
    if (isClosed) return;
    final current = state;
    if (current is! ReplayShowing || !current.playing || current.atEnd) return;
    _show(current, index: current.index + 1, playing: true, reset: false, animate: true);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
