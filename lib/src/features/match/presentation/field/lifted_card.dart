import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Захваченный Чучелом отряд (макет 14, ступень B): карта приподнята в ×1,25 над рядом и соседями, у неё тень, золотая
/// рамка, видна сила и значок возврата ↺.
///
/// Карта лежит поверх рядов и ровно над своей копией в ряду ([rect]), касания пропускает. Так в плотном ряду, где
/// видна лишь полоска карты, игрок видит, какой отряд захвачен и сколько в нём силы.
class LiftedCard extends StatelessWidget {
  /// Создаёт приподнятую карту с лицом [face] на месте [rect] (размер карты в ряду).
  const LiftedCard({super.key, required this.face, required this.rect});

  /// Во сколько раз карта крупнее своей копии в ряду.
  static const double scale = 1.25;

  /// Диаметр значка возврата ↺.
  static const double badgeSize = 22;

  /// Рост карты за 120 мс; при «Уменьшить движение» сразу.
  static const Duration rise = Duration(milliseconds: 120);

  /// Лицо захваченной карты.
  final CardFace face;

  /// Место карты в ряду в координатах поля.
  final Rect rect;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : rise;
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: scale),
          duration: duration,
          curve: Curves.easeOut,
          builder: (context, scale, card) => Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Transform.scale(scale: scale, child: card),
              ),
              // Значок на верхнем правом углу увеличенной карты, чуть выступая за неё.
              Positioned(
                left: rect.width / 2 + rect.width * scale / 2 - badgeSize + 8,
                top: rect.height / 2 - rect.height * scale / 2 - 8,
                child: const _Badge(),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [
                BoxShadow(color: Color(0xA6000000), offset: Offset(0, 6), blurRadius: 13),
                BoxShadow(color: GwentColors.gold, spreadRadius: 1.6),
              ],
            ),
            child: GwentCard(face: face, size: CardSize.row),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(shape: BoxShape.circle, color: GwentColors.gold),
    child: SizedBox.square(
      dimension: LiftedCard.badgeSize,
      child: CustomPaint(painter: _ReturnArrowPainter()),
    ),
  );
}

/// Стрелка возврата ↺ тёмным по золоту: дуга против часовой стрелки с наконечником. Рисуется, а не печатается:
/// гарнитуры игры значка ↺ не содержат.
class _ReturnArrowPainter extends CustomPainter {
  const _ReturnArrowPainter();

  static const Color _ink = Color(0xFF1E160D);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.27;
    const start = -math.pi / 4;
    const sweep = -math.pi * 1.5;
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, stroke);
    // Наконечник на конце дуги, по касательной против часовой стрелки.
    const end = start + sweep;
    final tip = center + Offset(math.cos(end), math.sin(end)) * radius;
    final tangent = Offset(math.sin(end), -math.cos(end));
    final normal = Offset(math.cos(end), math.sin(end));
    final head = Path()
      ..moveTo(tip.dx + tangent.dx * 3.2, tip.dy + tangent.dy * 3.2)
      ..lineTo(tip.dx + normal.dx * 2.6, tip.dy + normal.dy * 2.6)
      ..lineTo(tip.dx - normal.dx * 2.6, tip.dy - normal.dy * 2.6)
      ..close();
    canvas.drawPath(head, Paint()..color = _ink);
  }

  @override
  bool shouldRepaint(_ReturnArrowPainter oldDelegate) => false;
}
