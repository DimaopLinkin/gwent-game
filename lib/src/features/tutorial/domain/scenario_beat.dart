import 'package:gwent/src/features/tutorial/domain/hint_target.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_move.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_step.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Одно звено сценария: показ, ход игрока или ход бота. Сценарий идёт строго по порядку (ADR 0034).
sealed class Beat extends Value {
  const Beat();
}

/// Показ: карточка подсказки с кнопкой «Дальше», ход в партии не нужен.
final class ShowBeat extends Beat {
  /// Создаёт показ; [targets] подсвечиваются окнами.
  const ShowBeat(this.step, this.targets);

  /// Шаг, текст которого показывается.
  final TutorialStep step;

  /// Что подсвечено.
  final List<HintTarget> targets;

  @override
  List<Object?> get props => [step, targets];
}

/// Ход игрока. Без [step] это свободный ход: подсвечены карта и цель, карточки подсказки нет.
final class PlayerBeat extends Beat {
  /// Создаёт ход игрока.
  const PlayerBeat(this.move, {this.step, this.targets = const []});

  /// Что нужно сыграть.
  final TutorialMove move;

  /// Шаг с карточкой; `null` у свободного хода.
  final TutorialStep? step;

  /// Что подсвечено, кроме карты и её цели (у паса это счёт и кнопка).
  final List<HintTarget> targets;

  @override
  List<Object?> get props => [move, step, targets];
}

/// Ход бота, заданный заранее: бот не думает, а делает ровно его.
final class BotBeat extends Beat {
  /// Создаёт ход бота.
  const BotBeat(this.move);

  /// Что бот делает.
  final TutorialMove move;

  @override
  List<Object?> get props => [move];
}
