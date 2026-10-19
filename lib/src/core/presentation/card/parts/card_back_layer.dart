import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/parts/dashed_rrect_painter.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';

/// Рубашка: тёмная кожа, прострочка и герб фракции по центру.
class CardBackLayer extends StatelessWidget {
  /// Создаёт рубашку фракции [faction].
  const CardBackLayer({super.key, required this.faction, required this.metrics});

  /// Фракция колоды.
  final GwentFaction faction;

  /// Размеры карты.
  final CardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final crest = faction.crest;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [GwentColors.backLeather, GwentColors.backLeatherEdge],
          stops: [0, 0.75],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(metrics.stitchInset),
              child: CustomPaint(
                painter: DashedRRectPainter(
                  color: GwentColors.gold.withValues(alpha: 0.4),
                  strokeWidth: 1,
                  radius: metrics.innerRadius,
                ),
              ),
            ),
          ),
          if (crest != null) GwentIconView(crest, size: metrics.crest),
        ],
      ),
    );
  }
}
