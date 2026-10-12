import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Метка способности лидера справа сверху (L7): золотой ромб — доступна, пустой перечёркнутый — использована.
///
/// В полном просмотре рядом с ромбом подпись «Доступна» или «Использована».
class LeaderMarker extends StatelessWidget {
  /// Создаёт метку.
  const LeaderMarker({super.key, required this.used, required this.metrics});

  /// Способность использована.
  final bool used;

  /// Размеры карты.
  final CardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final l10n = context.l10n;
    final side = m.leaderMarker;
    final diamond = Transform.rotate(
      angle: math.pi / 4,
      child: used
          ? Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                color: GwentColors.bg,
                border: Border.all(color: GwentColors.muted, width: 1.5),
              ),
              child: OverflowBox(
                maxWidth: side * 1.6,
                child: Container(width: side * 1.6, height: 1.5, color: GwentColors.muted),
              ),
            )
          : Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [GwentColors.goldHighlight, GwentColors.brassLight],
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xB3C8A35B), blurRadius: m.glow),
                  const BoxShadow(color: GwentColors.bg, spreadRadius: 1),
                ],
              ),
            ),
    );
    if (m.leaderLabelFontSize == 0) return diamond;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: m.columnGap,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: used ? GwentColors.surfaceRaised : GwentColors.gold,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              used ? l10n.cardLeaderAbilityUsed : l10n.cardLeaderAbilityReady,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: GwentText.cormorant,
                fontWeight: FontWeight.w700,
                fontSize: m.leaderLabelFontSize,
                height: 1,
                letterSpacing: m.leaderLabelFontSize * 0.06,
                color: used ? GwentColors.textSecondary : GwentColors.onGold,
              ),
            ),
          ),
        ),
        diamond,
      ],
    );
  }
}
