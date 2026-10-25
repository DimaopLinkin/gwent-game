import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/parts/card_coin.dart';
import 'package:gwent/src/core/presentation/card/parts/power_medallion.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Сжатая сила и способность карты в тесном ряду: число, стрелка и значок способности друг под другом в видимой
/// полоске шириной [width].
///
/// Нужна, когда карты лежат внахлёст с шагом меньше медальона и следующая карта закрывает его. Число стоит прямо на
/// арте, с тёмной обводкой, чтобы читаться на любом фоне. Цвет и стрелка те же, что у [PowerMedallion], поэтому
/// усиление и ослабление читаются так же. Значок ряда не рисуется: ряд и так понятен, а способность остаётся.
class CompactPower extends StatelessWidget {
  /// Создаёт сжатую силу [power] и способность [ability] шириной [width].
  const CompactPower({super.key, required this.power, required this.look, required this.width, this.ability});

  /// Текущая сила.
  final int power;

  /// Вид медальона.
  final PowerLook look;

  /// Ширина видимой полоски карты.
  final double width;

  /// Способность карты; `null` у карты без способности.
  final GwentIcon? ability;

  /// Наибольший диаметр монеты способности.
  static const double maxCoin = 12;

  /// Кегль числа.
  static const double fontSize = 14;

  @override
  Widget build(BuildContext context) {
    final color = switch (look) {
      PowerLook.base => GwentColors.parchmentHighlight,
      PowerLook.buffed => GwentColors.buff,
      PowerLook.debuffed => GwentColors.debuff,
      PowerLook.hero => GwentColors.goldHighlight,
    };
    final arrow = switch (look) {
      PowerLook.buffed => GwentIcon.iconPowerUp,
      PowerLook.debuffed => GwentIcon.iconPowerDown,
      PowerLook.base || PowerLook.hero => null,
    };
    final style = GwentText.powerCard.copyWith(fontWeight: FontWeight.w900, fontSize: fontSize);
    // Между соседними картами остаётся зазор 1 pt, чтобы значки не сливались.
    final inner = math.max(0.0, width - 1);
    // Тонкий ободок монеты (0,75 pt с каждой стороны) тоже должен уложиться в полоску.
    final coin = (inner - 1.5).clamp(0.0, maxCoin);
    return SizedBox(
      width: inner,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 1,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Stack(
              children: [
                ExcludeSemantics(
                  child: Text(
                    '$power',
                    textScaler: TextScaler.noScaling,
                    style: style.copyWith(
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 3
                        ..strokeJoin = StrokeJoin.round
                        ..color = GwentColors.bg,
                    ),
                  ),
                ),
                Text(
                  '$power',
                  textScaler: TextScaler.noScaling,
                  style: style.copyWith(color: color),
                ),
              ],
            ),
          ),
          if (arrow != null) GwentIconView(arrow, size: 7, color: color),
          if (ability != null && coin > 0)
            CardCoin.effect(
              icon: ability!,
              diameter: coin,
              iconSize: coin * 0.7,
              rings: const [BoxShadow(color: GwentColors.brassDeep, spreadRadius: 0.75)],
            ),
        ],
      ),
    );
  }
}
