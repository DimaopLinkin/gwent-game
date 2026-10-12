import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_weather.dart';

/// Погода на ряду (макет дизайн-системы, `weatherOverlay`): слой над артом карт и под цифрами силы.
///
/// Рисует иней, туман или дождь; для остальной погоды ([GwentWeather.skelligeStorm] раскладывается экраном на туман и
/// ливень по рядам, [GwentWeather.clear] снимает оверлей) слой пуст. Слой не принимает касаний. Ясное небо: оверлей гаснет за
/// [fadeDuration]. При «уменьшить движение» туман и дождь статичны.
class RowWeatherOverlay extends StatefulWidget {
  /// Создаёт слой погоды [weather] на ряду; `null` — без погоды.
  const RowWeatherOverlay({super.key, required this.weather});

  /// Сколько гаснет слой.
  static const Duration fadeDuration = Duration(milliseconds: 400);

  /// Погода на ряду.
  final GwentWeather? weather;

  @override
  State<RowWeatherOverlay> createState() => _RowWeatherOverlayState();
}

class _RowWeatherOverlayState extends State<RowWeatherOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 16));
  GwentWeather? _shown;

  static bool _hasOverlay(GwentWeather? weather) =>
      weather == GwentWeather.frost || weather == GwentWeather.fog || weather == GwentWeather.rain;

  @override
  void initState() {
    super.initState();
    _shown = _hasOverlay(widget.weather) ? widget.weather : null;
  }

  @override
  void didUpdateWidget(RowWeatherOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Пока слой гаснет, остаётся прежняя погода, иначе он исчез бы мгновенно.
    if (_hasOverlay(widget.weather)) _shown = widget.weather;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (animate && !_drift.isAnimating) {
      unawaited(_drift.repeat());
    } else if (!animate) {
      _drift
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          opacity: _hasOverlay(widget.weather) ? 1 : 0,
          duration: RowWeatherOverlay.fadeDuration,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _drift,
              builder: (context, _) => CustomPaint(
                painter: _WeatherPainter(
                  weather: shown,
                  drift: _drift.value,
                  seconds: _drift.duration!.inMilliseconds / 1000,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  const _WeatherPainter({required this.weather, required this.drift, required this.seconds});

  final GwentWeather weather;

  /// Доля оборота 16-секундного цикла.
  final double drift;
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    switch (weather) {
      case GwentWeather.frost:
        _frost(canvas, size);
      case GwentWeather.fog:
        _fog(canvas, size);
      case GwentWeather.rain:
        _rain(canvas, size);
      case GwentWeather.skelligeStorm || GwentWeather.clear:
        break;
    }
    canvas.restore();
  }

  /// Иней по краям ряда, центр чистый, поверх тонкая сетка кристаллов. Статичный.
  void _frost(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const tint = GwentColors.frostTint;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFBED7EB).withValues(alpha: 0.28),
            const Color(0xFFBED7EB).withValues(alpha: 0.06),
            const Color(0xFFBED7EB).withValues(alpha: 0.24),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
    // Иней с краёв: эллипс 28 % × 130 % с центром на краю ряда; круг единичного радиуса растягивается масштабом.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [tint.withValues(alpha: 0.55), tint.withValues(alpha: 0)],
        stops: const [0, 0.7],
      ).createShader(const Rect.fromLTRB(-1, -1, 1, 1));
    for (final edge in [0.0, size.width]) {
      canvas
        ..save()
        ..translate(edge, size.height / 2)
        ..scale(size.width * 0.28, size.height * 1.3)
        ..drawRect(const Rect.fromLTRB(-1, -1, 1, 1), glow)
        ..restore();
    }
    final lattice = Paint()
      ..color = const Color(0x14E1EEFA)
      ..strokeWidth = 1;
    final slope = math.tan(math.pi / 6);
    for (var x = -size.height * slope; x < size.width + size.height * slope; x += 7) {
      canvas
        ..drawLine(Offset(x, 0), Offset(x + size.height * slope, size.height), lattice)
        ..drawLine(Offset(x + size.height * slope, 0), Offset(x, size.height), lattice);
    }
    canvas
      ..save()
      ..clipRect(rect)
      ..drawRect(
        rect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..color = const Color(0x80D2E6F5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      )
      ..restore()
      ..drawRect(
        rect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0x59D2E6F5),
      );
  }

  /// Две полосы тёплого тумана дрейфуют влево: циклы 240 и 360 pt за 16 с.
  void _fog(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x1AC8C3B9));
    void band({
      required double period,
      required double width,
      required double height,
      required double y,
      required double alpha,
    }) {
      final paint = Paint()
        ..color = GwentWeather.fog.tint.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, height / 2);
      final shift = drift * period;
      for (var x = period / 4 - shift - period; x < size.width + width; x += period) {
        canvas.drawOval(Rect.fromCenter(center: Offset(x, size.height * y), width: width, height: height), paint);
      }
    }

    band(period: 240, width: 120, height: 26, y: 0.32, alpha: 0.42);
    band(period: 360, width: 180, height: 30, y: 0.74, alpha: 0.34);
  }

  /// Штрихи капель с наклоном 12°, цикл 0,7 с, затемнение ряда 24 %.
  void _rain(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x3D19202C));
    final cycles = seconds / 0.7;
    final t = (drift * cycles) % 1;
    canvas
      ..save()
      ..translate(size.width / 2, 0)
      ..transform(Matrix4.skewX(-math.tan(12 * math.pi / 180)).storage)
      ..translate(-size.width / 2 - 24, 0);
    void streaks({
      required double cellW,
      required double cellH,
      required double len,
      required double alpha,
      required double dx,
      required double dy,
    }) {
      final paint = Paint()
        ..color = const Color(0xFFC3D4E6).withValues(alpha: alpha)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      for (var y = -cellH + dy; y < size.height + cellH; y += cellH) {
        for (var x = dx; x < size.width + 48; x += cellW) {
          canvas.drawLine(Offset(x, y + t * cellH * 2), Offset(x, y + t * cellH * 2 + len), paint);
        }
      }
    }

    streaks(cellW: 9, cellH: 23, len: 6, alpha: 0.75, dx: 4.5, dy: 0);
    streaks(cellW: 13, cellH: 31, len: 5, alpha: 0.5, dx: 11, dy: 11);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WeatherPainter oldDelegate) => oldDelegate.weather != weather || oldDelegate.drift != drift;
}
