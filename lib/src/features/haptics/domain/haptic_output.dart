import 'package:gwent/src/features/haptics/domain/haptic_pattern.dart';

/// Вывод вибрации (ADR 0031): за ним стоит вибромотор телефона. Реализация живёт в слое data.
abstract interface class HapticOutput {
  /// Проигрывает [pattern]. Не ждёт конца паттерна; новый паттерн обрывает недоигранный.
  void play(HapticPattern pattern);
}
