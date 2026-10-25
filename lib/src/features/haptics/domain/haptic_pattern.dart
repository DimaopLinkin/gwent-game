import 'package:meta/meta.dart';

/// Сила одного касания вибромотора.
enum HapticStrength {
  /// Едва заметный щелчок.
  tick,

  /// Лёгкий удар.
  soft,

  /// Обычный удар.
  medium,

  /// Тяжёлый удар.
  heavy,
}

/// Одно касание паттерна: [strength] через [after] после предыдущего (у первого касания пауза не нужна).
@immutable
final class HapticStep {
  /// Создаёт касание.
  const HapticStep(this.strength, {this.after = Duration.zero});

  /// Сила касания.
  final HapticStrength strength;

  /// Пауза после предыдущего касания.
  final Duration after;
}

/// Паттерн вибрации: короткая последовательность касаний (docs/adr/0031-haptics.md).
///
/// Названия говорят о форме паттерна, а не о событии: какой паттерн у какого события, решает [SoundHaptics] и
/// прицеливание. Паузы между касаниями 60–110 мс, сила нарастает с «весом» события.
enum HapticPattern {
  /// Едва заметный щелчок.
  tick([HapticStep(HapticStrength.tick)]),

  /// Лёгкий удар.
  soft([HapticStep(HapticStrength.soft)]),

  /// Обычный удар.
  medium([HapticStep(HapticStrength.medium)]),

  /// Тяжёлый удар.
  heavy([HapticStep(HapticStrength.heavy)]),

  /// «Тук-тук»: два лёгких удара.
  double([HapticStep(HapticStrength.soft), HapticStep(HapticStrength.soft, after: _short)]),

  /// Быстрая дробь из трёх лёгких ударов.
  triple([
    HapticStep(HapticStrength.soft),
    HapticStep(HapticStrength.soft, after: _tight),
    HapticStep(HapticStrength.soft, after: _tight),
  ]),

  /// Посадка и «осела»: обычный удар и лёгкий следом.
  knock([HapticStep(HapticStrength.medium), HapticStep(HapticStrength.soft, after: _medium)]),

  /// Волна, которая затухает: погода.
  ripple([
    HapticStep(HapticStrength.medium),
    HapticStep(HapticStrength.soft, after: _tight),
    HapticStep(HapticStrength.tick, after: _tight),
  ]),

  /// Рокот: Казнь.
  rumble([
    HapticStep(HapticStrength.heavy),
    HapticStep(HapticStrength.medium, after: _tight),
    HapticStep(HapticStrength.medium, after: _tight),
    HapticStep(HapticStrength.soft, after: _tight),
  ]),

  /// Нарастание: победа.
  rise([
    HapticStep(HapticStrength.tick),
    HapticStep(HapticStrength.soft, after: _short),
    HapticStep(HapticStrength.medium, after: _short),
    HapticStep(HapticStrength.heavy, after: _short),
  ]),

  /// Нарастание и тяжёлый финальный удар: победа в матче.
  triumph([
    HapticStep(HapticStrength.tick),
    HapticStep(HapticStrength.soft, after: _short),
    HapticStep(HapticStrength.medium, after: _short),
    HapticStep(HapticStrength.heavy, after: _short),
    HapticStep(HapticStrength.heavy, after: _long),
  ]),

  /// Затухание: поражение.
  fall([
    HapticStep(HapticStrength.heavy),
    HapticStep(HapticStrength.medium, after: _long),
    HapticStep(HapticStrength.soft, after: _long),
  ]),

  /// Отказ: два обычных удара.
  warn([HapticStep(HapticStrength.medium), HapticStep(HapticStrength.medium, after: _warnGap)])
  ;

  const HapticPattern(this.steps);

  static const Duration _tight = Duration(milliseconds: 60);
  static const Duration _short = Duration(milliseconds: 70);
  static const Duration _medium = Duration(milliseconds: 80);
  static const Duration _warnGap = Duration(milliseconds: 90);
  static const Duration _long = Duration(milliseconds: 110);

  /// Касания паттерна по порядку.
  final List<HapticStep> steps;
}
