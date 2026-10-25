import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/parts/card_coin.dart';
import 'package:gwent/src/core/presentation/card/parts/power_medallion.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';

/// Сжатая сила и способности карты в тесном ряду: узкий медальон силы и под ним монеты способностей в видимой
/// полоске шириной [width].
///
/// Нужна, когда карты лежат внахлёст с шагом меньше медальона и следующая карта закрывает его. Медальон тот же, что на
/// обычной карте (цвет и кольца для базовой силы, усиления, ослабления и героя), но без стрелки: усиление и
/// ослабление видно по цвету. Число ужимается по ширине.
class CompactPower extends StatelessWidget {
  /// Создаёт сжатую силу [power] и способности [abilities] шириной [width].
  const CompactPower({
    super.key,
    required this.power,
    required this.look,
    required this.width,
    this.abilities = const [],
  });

  /// Текущая сила.
  final int power;

  /// Вид медальона.
  final PowerLook look;

  /// Ширина видимой полоски карты.
  final double width;

  /// Способности карты (в том числе проворство); пусто у карты без способностей.
  final List<GwentIcon> abilities;

  /// Наибольший диаметр монеты способности.
  static const double maxCoin = 12;

  @override
  Widget build(BuildContext context) {
    // Между соседними картами остаётся зазор 1 pt, чтобы медальоны не сливались.
    final inner = math.max(0.0, width - 1);
    // Тонкий ободок монеты (0,75 pt с каждой стороны) тоже должен уложиться в полоску.
    final coin = (inner - 1.5).clamp(0.0, maxCoin);
    return SizedBox(
      width: inner,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          PowerMedallion(power: power, look: look, metrics: CardSize.row.metrics, compactWidth: inner),
          if (coin > 0)
            for (final ability in abilities)
              CardCoin.effect(
                icon: ability,
                diameter: coin,
                iconSize: coin * 0.7,
                rings: const [BoxShadow(color: GwentColors.brassDeep, spreadRadius: 0.75)],
              ),
        ],
      ),
    );
  }
}
