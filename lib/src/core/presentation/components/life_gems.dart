import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Камни-жизни игрока (макет дизайн-системы, `lifeGems`): целый камень — красный самоцвет, потерянный — пустое гнездо
/// с трещиной, поэтому состояние читается и без цвета.
class LifeGems extends StatelessWidget {
  /// Создаёт ряд из [total] камней, из которых целы [remaining].
  const LifeGems({super.key, required this.remaining, this.total = 2, this.size = 18, this.gap = 6})
    : assert(remaining >= 0 && remaining <= total, 'remaining вне 0…total');

  /// Сколько камней осталось.
  final int remaining;

  /// Сколько камней всего (кристаллов в партии).
  final int total;

  /// Диаметр камня: 18 pt отдельно, 14 pt на плашке игрока.
  final double size;

  /// Промежуток между камнями.
  final double gap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.lifeGemsSemantics(remaining, total),
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [for (var i = 0; i < total; i++) LifeGem(lost: i >= remaining, size: size)],
    ),
  );
}

/// Один камень-жизнь.
class LifeGem extends StatelessWidget {
  /// Создаёт камень; [lost] — потерян.
  const LifeGem({super.key, required this.lost, this.size = 18});

  /// Камень потерян.
  final bool lost;

  /// Диаметр.
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: lost
        ? CustomPaint(painter: _LostGemPainter())
        : const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.4),
                radius: 0.75,
                colors: [GwentColors.lifeGemHighlight, GwentColors.lifeGem, GwentColors.lifeGemDeep],
                stops: [0, 0.45, 1],
              ),
              boxShadow: [
                BoxShadow(color: Color(0x99000000), offset: Offset(0, 1), blurRadius: 2),
                BoxShadow(color: GwentColors.brass, spreadRadius: 1),
              ],
            ),
          ),
  );
}

class _LostGemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas
      ..drawCircle(center, radius + 0.5, Paint()..color = GwentColors.line)
      ..drawCircle(center, radius - 0.5, Paint()..color = GwentColors.socket)
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(0.4887)
      ..drawLine(
        Offset(0, -radius * 0.78),
        Offset(0, radius * 0.78),
        Paint()
          ..color = GwentColors.line
          ..strokeWidth = 1.5,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_LostGemPainter oldDelegate) => false;
}
