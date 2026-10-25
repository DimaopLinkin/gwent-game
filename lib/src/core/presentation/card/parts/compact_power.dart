import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/parts/power_medallion.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Сжатая сила карты в тесном ряду: узкая «таблетка» шириной [width] вместо медальона.
///
/// Нужна, когда карты лежат внахлёст с шагом меньше медальона и следующая карта закрывает его: число и стрелка
/// усиления стоят друг над другом и целиком помещаются в видимую полоску карты. Цвет, стрелка и кольцо те же, что
/// у [PowerMedallion], поэтому усиление и ослабление читаются так же.
class CompactPower extends StatelessWidget {
  /// Создаёт сжатую силу [power] шириной [width].
  const CompactPower({super.key, required this.power, required this.look, required this.width});

  /// Текущая сила.
  final int power;

  /// Вид медальона.
  final PowerLook look;

  /// Ширина видимой полоски карты.
  final double width;

  /// Высота таблетки: число и под ним стрелка.
  static const double height = 24;

  /// Высота таблетки без стрелки.
  static const double plainHeight = 16;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color text, Color ring) = switch (look) {
      PowerLook.base => (GwentColors.parchment, GwentColors.bg, GwentColors.brass),
      PowerLook.buffed => (GwentColors.bg, GwentColors.buff, GwentColors.buff),
      PowerLook.debuffed => (GwentColors.bg, GwentColors.debuff, GwentColors.debuff),
      PowerLook.hero => (GwentColors.gold, GwentColors.onGold, GwentColors.brassDark),
    };
    final arrow = switch (look) {
      PowerLook.buffed => GwentIcon.iconPowerUp,
      PowerLook.debuffed => GwentIcon.iconPowerDown,
      PowerLook.base || PowerLook.hero => null,
    };
    // Между таблетками остаётся зазор 1 pt, чтобы кольца соседних карт не сливались.
    final pill = width - 1;
    return Container(
      width: pill,
      height: arrow == null ? plainHeight : height,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(pill / 2),
        border: Border.all(color: ring),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$power',
                textScaler: TextScaler.noScaling,
                style: GwentText.powerCard.copyWith(fontWeight: FontWeight.w900, fontSize: 11, color: text),
              ),
            ),
          ),
          if (arrow != null) GwentIconView(arrow, size: 6, color: text),
        ],
      ),
    );
  }
}
