import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Как показана сила (макет карты, «Состояния силы»). Цвет всегда идёт вместе со стрелкой и обводкой.
enum PowerLook {
  /// Базовая: пергаментный круг, тёмное число.
  base,

  /// Выше базовой: зелёное число со стрелкой ▲ и зелёное кольцо.
  buffed,

  /// Ниже базовой: красное число со стрелкой ▼ и красное кольцо.
  debuffed,

  /// Герой: золотой медальон с тройным кольцом, сила не меняется.
  hero,
}

/// Медальон силы в колонке слева сверху (L6).
class PowerMedallion extends StatelessWidget {
  /// Создаёт медальон силы [power].
  const PowerMedallion({
    super.key,
    required this.power,
    required this.look,
    required this.metrics,
    this.compactWidth,
  });

  /// Текущая сила.
  final int power;

  /// Вид медальона.
  final PowerLook look;

  /// Размеры карты.
  final CardMetrics metrics;

  /// Ширина сжатого медальона в тесном ряду: без стрелки, число ужимается, кольца те же. `null` — обычный медальон.
  final double? compactWidth;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final (r1, r2, r3) = m.rings;
    final drop = BoxShadow(color: const Color(0x99000000), offset: Offset(0, m.shadowY / 2), blurRadius: m.shadowY);
    final (Gradient? gradient, Color? fill, Color text, List<BoxShadow> rings) = switch (look) {
      PowerLook.base => (
        const RadialGradient(
          center: Alignment(-0.2, -0.4),
          radius: 0.9,
          colors: [GwentColors.parchmentHighlight, GwentColors.parchment, GwentColors.parchmentLow],
          stops: [0, 0.55, 1],
        ),
        null,
        GwentColors.bg,
        [
          drop,
          BoxShadow(color: GwentColors.bg, spreadRadius: r2),
          BoxShadow(color: GwentColors.brass, spreadRadius: r1),
        ],
      ),
      PowerLook.buffed => (
        null,
        GwentColors.bg,
        GwentColors.buff,
        [BoxShadow(color: GwentColors.bg, spreadRadius: r2), BoxShadow(color: GwentColors.buff, spreadRadius: r1)],
      ),
      PowerLook.debuffed => (
        null,
        GwentColors.bg,
        GwentColors.debuff,
        [BoxShadow(color: GwentColors.bg, spreadRadius: r2), BoxShadow(color: GwentColors.debuff, spreadRadius: r1)],
      ),
      PowerLook.hero => (
        const RadialGradient(
          center: Alignment(-0.2, -0.4),
          radius: 0.9,
          colors: [GwentColors.goldHighlight, GwentColors.gold, GwentColors.brass],
          stops: [0, 0.5, 1],
        ),
        null,
        GwentColors.onGold,
        [
          BoxShadow(color: const Color(0x73C8A35B), blurRadius: m.glow),
          BoxShadow(color: GwentColors.gold, spreadRadius: r3),
          BoxShadow(color: GwentColors.bg, spreadRadius: r2),
          BoxShadow(color: GwentColors.brassDark, spreadRadius: r1),
        ],
      ),
    };
    final compactWidth = this.compactWidth;
    final arrow = compactWidth != null
        ? null
        : switch (look) {
            PowerLook.buffed => GwentIcon.iconPowerUp,
            PowerLook.debuffed => GwentIcon.iconPowerDown,
            PowerLook.base || PowerLook.hero => null,
          };
    // Кольца рисуются тенями за пределами диска: в сжатом виде они тоже должны уложиться в [compactWidth].
    final discWidth = compactWidth == null
        ? null
        : math.max(0.0, compactWidth - 2 * (look == PowerLook.hero ? r3 : r2));
    final label = Text(
      '$power',
      textScaler: TextScaler.noScaling,
      style: GwentText.powerCard.copyWith(fontWeight: FontWeight.w900, fontSize: m.powerFontSize, color: text),
    );
    return Container(
      width: discWidth,
      constraints: BoxConstraints(minWidth: discWidth ?? m.disc),
      height: m.disc,
      padding: EdgeInsets.symmetric(horizontal: discWidth == null ? m.discPadding : 0),
      decoration: BoxDecoration(
        color: fill,
        gradient: gradient,
        borderRadius: BorderRadius.circular(m.disc / 2),
        boxShadow: rings,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: m.arrowGap,
        children: [
          if (arrow != null) GwentIconView(arrow, size: m.arrow, color: text),
          if (discWidth == null)
            label
          else
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, child: label),
            ),
        ],
      ),
    );
  }
}
