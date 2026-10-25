import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gwent/src/features/haptics/domain/haptic_output.dart';
import 'package:gwent/src/features/haptics/domain/haptic_pattern.dart';

/// Вибрация через `HapticFeedback` Flutter (ADR 0031): на iPhone это Taptic Engine (`UIImpactFeedbackGenerator`), на
/// Android системные константы касания.
///
/// Паттерн собирается из касаний с паузами. Новый паттерн обрывает недоигранный: хвост устаревшего паттерна только
/// шумел бы. Сбой платформы не роняет игру: он уходит в `FlutterError.reportError`.
final class FlutterHapticOutput implements HapticOutput {
  /// Создаёт вывод. [impact] и [delay] подменяются в тестах.
  FlutterHapticOutput({
    Future<void> Function(HapticStrength strength)? impact,
    Future<void> Function(Duration duration)? delay,
  }) : _impact = impact ?? _platformImpact,
       _delay = delay ?? _systemDelay;

  final Future<void> Function(HapticStrength strength) _impact;
  final Future<void> Function(Duration duration) _delay;
  int _generation = 0;

  @override
  void play(HapticPattern pattern) {
    final generation = ++_generation;
    unawaited(_run(pattern, generation));
  }

  Future<void> _run(HapticPattern pattern, int generation) async {
    try {
      for (final step in pattern.steps) {
        if (step.after > Duration.zero) await _delay(step.after);
        if (generation != _generation) return;
        await _impact(step.strength);
      }
    } on Exception catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'haptics', context: ErrorDescription('вибрация')),
      );
    }
  }

  static Future<void> _platformImpact(HapticStrength strength) => switch (strength) {
    HapticStrength.tick => HapticFeedback.selectionClick(),
    HapticStrength.soft => HapticFeedback.lightImpact(),
    HapticStrength.medium => HapticFeedback.mediumImpact(),
    HapticStrength.heavy => HapticFeedback.heavyImpact(),
  };

  static Future<void> _systemDelay(Duration duration) => Future<void>.delayed(duration);
}
