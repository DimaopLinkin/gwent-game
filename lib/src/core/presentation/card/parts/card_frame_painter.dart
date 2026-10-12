import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Рамка карты (L5): вложенные обводки внутрь от края и внутреннее свечение (макет: inset box-shadow).
///
/// Отряд — латунь; герой — золото ×1,5, ромбы в углах и тёплое свечение; особая — светлая латунь; погода — цвет
/// погоды со свечением; лидер — золото и внутренний кант фракции; рубашка — латунь.
class CardFramePainter extends CustomPainter {
  /// Рамка для карты [face] размера [metrics].
  CardFramePainter({required CardFace face, required this.metrics}) : _frame = _CardFrame.of(face, metrics);

  /// Размеры карты.
  final CardMetrics metrics;

  final _CardFrame _frame;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(metrics.radius));
    final glow = _frame.glow;
    if (glow != null) {
      canvas
        ..save()
        ..clipRRect(outer)
        ..drawRRect(
          outer,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = glow.radius
            ..color = glow.color
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow.radius / 2),
        )
        ..restore();
    }
    var inset = 0.0;
    for (final band in _frame.bands) {
      final rect = outer.deflate(inset + band.width / 2);
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = band.width
          ..color = band.color,
      );
      inset += band.width;
    }
    if (_frame.ornaments) _paintOrnaments(canvas, size);
  }

  /// Ромбы героя: справа сверху, слева снизу и справа снизу.
  void _paintOrnaments(Canvas canvas, Size size) {
    final side = metrics.ornament;
    final offset = metrics.ornamentInset + side / 2;
    final centers = [
      Offset(size.width - offset, offset),
      Offset(offset, size.height - offset),
      Offset(size.width - offset, size.height - offset),
    ];
    final fill = Paint()..color = GwentColors.gold;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = GwentColors.bg;
    for (final center in centers) {
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(math.pi / 4);
      final square = Rect.fromCenter(center: Offset.zero, width: side, height: side);
      canvas
        ..drawRect(square.inflate(0.5), edge)
        ..drawRect(square, fill)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(CardFramePainter oldDelegate) => oldDelegate.metrics != metrics || oldDelegate._frame != _frame;
}

/// Обводка шириной [width] цвета [color].
@immutable
final class _Band {
  const _Band(this.width, this.color);

  final double width;
  final Color color;

  @override
  bool operator ==(Object other) => other is _Band && other.width == width && other.color == color;

  @override
  int get hashCode => Object.hash(width, color);
}

/// Внутреннее свечение радиусом [radius].
@immutable
final class _Glow {
  const _Glow(this.radius, this.color);

  final double radius;
  final Color color;

  @override
  bool operator ==(Object other) => other is _Glow && other.radius == radius && other.color == color;

  @override
  int get hashCode => Object.hash(radius, color);
}

/// Обводки от края внутрь, свечение и ромбы для варианта карты.
@immutable
final class _CardFrame {
  const _CardFrame(this.bands, {this.glow, this.ornaments = false});

  factory _CardFrame.of(CardFace face, CardMetrics m) {
    final fw = m.frameWidth;
    const dark = Color(0xE614110E);
    return switch (face) {
      UnitCardFace(isHero: true) => _CardFrame(
        [_Band(fw * 1.5, GwentColors.gold), const _Band(1, GwentColors.bg), const _Band(1, GwentColors.brass)],
        glow: _Glow(m.glow, const Color(0x59C8A35B)),
        ornaments: m != CardMetrics.mini,
      ),
      UnitCardFace() => _CardFrame([
        _Band(fw, GwentColors.brass),
        const _Band(1, dark),
        const _Band(1, Color(0x38C8A35B)),
      ]),
      SpecialCardFace() => _CardFrame([
        _Band(fw, GwentColors.brassLight),
        const _Band(1, dark),
        const _Band(1, Color(0x59C8A35B)),
      ]),
      WeatherCardFace(:final weather) => _CardFrame(
        [_Band(fw, weather.tint), const _Band(1, GwentColors.bg)],
        glow: _Glow(m.glow * 1.4, weather.tint.withValues(alpha: 0.55)),
      ),
      LeaderCardFace(:final faction) => _CardFrame([
        _Band(fw * 1.5, GwentColors.gold),
        const _Band(1, GwentColors.bg),
        _Band(1.5, faction.color),
      ]),
      CardBackFace() => _CardFrame([_Band(fw, GwentColors.brass), const _Band(1, dark)]),
    };
  }

  final List<_Band> bands;
  final _Glow? glow;
  final bool ornaments;

  @override
  bool operator ==(Object other) =>
      other is _CardFrame &&
      other.glow == glow &&
      other.ornaments == ornaments &&
      other.bands.length == bands.length &&
      Iterable<int>.generate(bands.length).every((i) => other.bands[i] == bands[i]);

  @override
  int get hashCode => Object.hash(Object.hashAll(bands), glow, ornaments);
}
