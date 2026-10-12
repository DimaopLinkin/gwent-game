import 'dart:ui';

import 'package:flutter/widgets.dart';

/// Пунктирная обводка скруглённого прямоугольника: контур шпиона и прострочка рубашки.
class DashedRRectPainter extends CustomPainter {
  /// Пунктир цвета [color] толщиной [strokeWidth] со скруглением [radius].
  const DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    this.dash = 4,
    this.gap = 3,
  });

  /// Цвет штрихов.
  final Color color;

  /// Толщина линии.
  final double strokeWidth;

  /// Радиус углов.
  final double radius;

  /// Длина штриха.
  final double dash;

  /// Длина промежутка.
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    for (final PathMetric metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += dash + gap) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}
