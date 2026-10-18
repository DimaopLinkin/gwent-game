import 'package:flutter/material.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Ползунок громкости (макет 10): тонкая дорожка и золотая ручка 22 pt в латунном кольце. Зона нажатия 44 pt по высоте.
///
/// Значение — целое от [min] до [max]. [onChangeEnd] вызывается, когда игрок отпустил ручку: по нему сохраняют значение,
/// а [onChanged] приходит на каждый сдвиг.
class GwentSlider extends StatelessWidget {
  /// Создаёт ползунок.
  const GwentSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
  });

  /// Текущее значение.
  final int value;

  /// Игрок сдвигает ручку.
  final ValueChanged<int> onChanged;

  /// Игрок отпустил ручку.
  final VoidCallback? onChangeEnd;

  /// Наименьшее значение.
  final int min;

  /// Наибольшее значение.
  final int max;

  /// Название для экранного диктора.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: SizedBox(
      height: 44,
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 4,
          activeTrackColor: GwentColors.brass,
          inactiveTrackColor: GwentColors.surfaceRaised,
          thumbShape: const _GoldThumb(),
          overlayShape: SliderComponentShape.noOverlay,
          trackShape: const RoundedRectSliderTrackShape(),
          tickMarkShape: SliderTickMarkShape.noTickMark,
          showValueIndicator: ShowValueIndicator.never,
        ),
        child: Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          semanticFormatterCallback: (_) => '$value',
          onChanged: (v) => onChanged(v.round()),
          onChangeEnd: onChangeEnd == null ? null : (_) => onChangeEnd!(),
        ),
      ),
    ),
  );
}

/// Ручка: золотой шар с бликом, тёмный кант и латунное кольцо.
class _GoldThumb extends SliderComponentShape {
  const _GoldThumb();

  static const double _radius = 11;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size.fromRadius(_radius + 3);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas
      ..drawCircle(center, _radius + 3, Paint()..color = GwentColors.brass)
      ..drawCircle(center, _radius + 2, Paint()..color = GwentColors.bg);
    canvas.drawCircle(
      center,
      _radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.44),
          colors: [GwentColors.goldHighlight, GwentColors.gold, GwentColors.brass],
          stops: [0, 0.52, 1],
        ).createShader(Rect.fromCircle(center: center, radius: _radius)),
    );
  }
}
