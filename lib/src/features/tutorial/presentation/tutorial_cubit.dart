import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/tutorial/application/mark_first_match_passed.dart';
import 'package:gwent/src/features/tutorial/domain/scenario_director.dart';
import 'package:gwent/src/features/tutorial/presentation/tutorial_state.dart';

/// Держатель слоя подсказок «Первой партии» (ADR 0034): повторяет текущее звено сценария, помнит, свернул ли игрок
/// карточку, и отмечает обучение пройденным, когда сценарий дошёл до конца.
///
/// Сам ничего не решает: что можно сыграть, говорит `ScenarioDirector`, а выбор игрока на поле держит `FieldCubit`.
final class TutorialCubit extends Cubit<TutorialState> {
  /// Создаёт держатель над [director]; [markPassed] вызывается один раз, когда сценарий закончен.
  TutorialCubit(ScenarioDirector director, {MarkFirstMatchPassed? markPassed})
    : _director = director,
      _markPassed = markPassed,
      super(TutorialState(beat: director.current)) {
    _subscriptions = [_director.changes.listen((_) => _onChanged()), _director.nudges.listen((_) => _onNudge())];
  }

  final ScenarioDirector _director;
  final MarkFirstMatchPassed? _markPassed;
  late final List<StreamSubscription<void>> _subscriptions;
  bool _marked = false;

  /// Игрок нажал «Дальше» на показе, который сейчас на экране.
  void acknowledge() {
    final shown = state.beat;
    if (shown != null) _director.acknowledge(shown);
  }

  /// Игрок тронул то, что сейчас не нужно: карточка напоминает, что делать.
  void nudge() => _director.nudge();

  /// Сворачивает карточку подсказки или разворачивает её.
  void toggleCollapsed() => emit(state.copyWith(collapsed: !state.collapsed));

  void _onChanged() {
    if (isClosed) return;
    emit(TutorialState(beat: _director.current));
    if (_director.isCompleted && !_marked) {
      _marked = true;
      unawaited(_mark());
    }
  }

  void _onNudge() {
    // Свёрнутая карточка напоминания не покажет: она разворачивается.
    if (isClosed || (state.nudged && !state.collapsed)) return;
    emit(state.copyWith(nudged: true, collapsed: false));
  }

  Future<void> _mark() async {
    try {
      await _markPassed?.call();
    } on Object catch (error, stackTrace) {
      // Флаг не сохранился: игрок пройдёт обучение ещё раз, партия от этого не страдает.
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
