import 'package:gwent/src/features/tutorial/domain/scenario_beat.dart';
import 'package:meta/meta.dart';

/// Что слой подсказок показывает сейчас.
@immutable
final class TutorialState {
  /// Создаёт состояние.
  const TutorialState({required this.beat, this.collapsed = false, this.nudged = false});

  /// Текущее звено сценария; `null`, когда сценарий закончен.
  final Beat? beat;

  /// Игрок свернул карточку подсказки: остаётся значок «?».
  final bool collapsed;

  /// Игрок сделал не то, чего ждёт сценарий, и карточка напоминает, что сейчас нужно; со сменой звена напоминание
  /// уходит.
  final bool nudged;

  /// Копия с другими значениями.
  TutorialState copyWith({Beat? beat, bool? collapsed, bool? nudged}) =>
      TutorialState(beat: beat ?? this.beat, collapsed: collapsed ?? this.collapsed, nudged: nudged ?? this.nudged);

  @override
  bool operator ==(Object other) =>
      other is TutorialState && other.beat == beat && other.collapsed == collapsed && other.nudged == nudged;

  @override
  int get hashCode => Object.hash(beat, collapsed, nudged);
}
