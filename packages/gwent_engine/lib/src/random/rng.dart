import 'package:gwent_engine/src/core/value.dart';

/// Генератор случайных чисел партии.
///
/// Неизменяемый: каждый вызов возвращает число и генератор для следующего вызова. Генератор хранится
/// в состоянии партии, поэтому `apply` остаётся чистой функцией, а партию можно воспроизвести по сиду
/// и журналу намерений (раздел 12 правил).
abstract interface class Rng {
  /// Равномерно распределённое число из `[0, max)` и генератор для следующего вызова. `max` от 1 до 2^32.
  (int, Rng) nextInt(int max);
}

/// SplitMix64 с сидом. Алгоритм зафиксирован в коде, а не взят из `dart:math`,
/// чтобы последовательность не зависела от версии SDK.
final class SeededRng extends Value implements Rng {
  const SeededRng(this.state);

  /// Внутреннее состояние; при создании партии это сид.
  final int state;

  // 64-битные константы собраны из половин: целиком такие литералы не помещаются в знаковый int.
  // Арифметика рассчитана на 64-битные int с переполнением, то есть на нативные платформы (не web).
  static const int _golden = 0x9E3779B9 << 32 | 0x7F4A7C15;
  static const int _mix1 = 0xBF58476D << 32 | 0x1CE4E5B9;
  static const int _mix2 = 0x94D049BB << 32 | 0x133111EB;
  static const int _range = 0x100000000;

  @override
  (int, Rng) nextInt(int max) {
    if (max < 1 || max > _range) {
      throw RangeError.range(max, 1, _range, 'max');
    }
    // Отбрасываем хвост диапазона, чтобы все остатки были равновероятны.
    final limit = _range - _range % max;
    var next = state;
    while (true) {
      next += _golden;
      var z = next;
      z = (z ^ (z >>> 30)) * _mix1;
      z = (z ^ (z >>> 27)) * _mix2;
      z ^= z >>> 31;
      final value = z >>> 32;
      if (value < limit) {
        return (value % max, SeededRng(next));
      }
    }
  }

  @override
  List<Object?> get props => [state];
}
