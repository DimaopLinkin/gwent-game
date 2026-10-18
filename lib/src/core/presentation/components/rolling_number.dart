import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Цвет подсветки числа.
enum RollTone {
  /// Без подсветки.
  none,

  /// Прирост: зелёная.
  gain,

  /// Потеря: красная.
  loss,
}

/// Число, которое прокручивается от [from] к [to]: цифры уезжают вверх, новые приезжают снизу.
@immutable
final class RollValue {
  /// Создаёт значение; [progress] 0 показывает [from], 1 показывает [to].
  const RollValue(this.from, this.to, {this.progress = 1, this.flash = 0, this.tone = RollTone.none});

  /// Число, с которого начинается прокрутка.
  final int from;

  /// Число, на котором она заканчивается.
  final int to;

  /// Доля прокрутки от 0 до 1.
  final double progress;

  /// Сила подсветки от 0 до 1.
  final double flash;

  /// Цвет подсветки.
  final RollTone tone;

  /// Прокрутка закончена и подсветки нет: число показывается как обычный текст.
  bool get settled => progress >= 1 && flash <= 0;

  /// Число, которое сейчас ближе к показанному.
  int get nearest => progress < 0.5 ? from : to;

  @override
  bool operator ==(Object other) =>
      other is RollValue &&
      other.from == from &&
      other.to == to &&
      other.progress == progress &&
      other.flash == flash &&
      other.tone == tone;

  @override
  int get hashCode => Object.hash(from, to, progress, flash, tone);

  @override
  String toString() => 'RollValue($from→$to, ${progress.toStringAsFixed(2)})';
}

/// Число с вертикальной прокруткой (анимации карт, макет 12): старое число уезжает вверх, новое приезжает снизу, а
/// цвет на время подсветки смещается к зелёному (прирост) или красному (потеря).
class RollingNumber extends StatelessWidget {
  /// Создаёт число.
  const RollingNumber(this.value, {super.key, required this.style});

  /// Что показать.
  final RollValue value;

  /// Стиль цифр: размер и цвет без подсветки.
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tone = switch (value.tone) {
      RollTone.none => null,
      RollTone.gain => GwentColors.buff,
      RollTone.loss => GwentColors.debuff,
    };
    final color = style.color;
    final shown = tone == null || color == null || value.flash <= 0
        ? style
        : style.copyWith(color: Color.lerp(color, tone, value.flash));
    if (value.progress >= 1) return Text('${value.to}', textScaler: TextScaler.noScaling, style: shown);
    final lineHeight = (style.fontSize ?? 14) * (style.height ?? 1.2);
    final progress = value.progress.clamp(0.0, 1.0);
    return ClipRect(
      child: SizedBox(
        height: lineHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, -progress * lineHeight),
              child: Text('${value.from}', textScaler: TextScaler.noScaling, style: shown),
            ),
            Transform.translate(
              offset: Offset(0, (1 - progress) * lineHeight),
              child: Text('${value.to}', textScaler: TextScaler.noScaling, style: shown),
            ),
          ],
        ),
      ),
    );
  }
}
