import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';

/// Материал круглого медальона с иконкой (L6).
enum CoinLook {
  /// Тёмная монета с латунным ободком и золотой иконкой: ряд.
  dark,

  /// Латунная монета с тёмной иконкой: способность, эффект особой карты.
  brass,
}

/// Круглый медальон с иконкой: ряд и способность под силой, эффект особой карты и погоды вместо силы.
class CardCoin extends StatelessWidget {
  /// Монета ряда или способности: тонкий ободок и тень.
  const CardCoin({
    super.key,
    required this.icon,
    required this.look,
    required this.diameter,
    required this.iconSize,
  }) : rings = null,
       tint = null;

  /// Медальон эффекта особой карты: латунь с кольцами как у медальона силы.
  const CardCoin.effect({
    super.key,
    required this.icon,
    required this.diameter,
    required this.iconSize,
    required List<BoxShadow> this.rings,
  }) : look = CoinLook.brass,
       tint = null;

  /// Медальон погоды: тёмный, иконка и кольцо цвета погоды.
  const CardCoin.weather({
    super.key,
    required this.icon,
    required this.diameter,
    required this.iconSize,
    required Color this.tint,
    required List<BoxShadow> this.rings,
  }) : look = CoinLook.dark;

  /// Иконка.
  final GwentIcon icon;

  /// Материал.
  final CoinLook look;

  /// Диаметр.
  final double diameter;

  /// Размер иконки.
  final double iconSize;

  /// Кольца вокруг медальона; `null` — ободок монеты.
  final List<BoxShadow>? rings;

  /// Цвет погоды; `null` — не погода.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final tint = this.tint;
    final (gradient, iconColor, cut, rim) = switch (look) {
      CoinLook.dark => (
        const RadialGradient(
          center: Alignment(0, -0.3),
          radius: 0.8,
          colors: [GwentColors.surfaceRaised, GwentColors.bg],
        ),
        tint ?? GwentColors.gold,
        GwentColors.bg,
        GwentColors.brass,
      ),
      CoinLook.brass => (
        const RadialGradient(
          center: Alignment(-0.2, -0.36),
          radius: 0.9,
          colors: [GwentColors.brassHighlight, GwentColors.brassLight, GwentColors.brassDark],
          stops: [0, 0.58, 1],
        ),
        GwentColors.onGold,
        GwentColors.brassCut,
        GwentColors.brassDeep,
      ),
    };
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow:
            rings ??
            [
              const BoxShadow(color: Color(0x99000000), offset: Offset(0, 1), blurRadius: 3),
              BoxShadow(color: rim, spreadRadius: 1),
            ],
      ),
      child: GwentIconView(icon, size: iconSize, color: iconColor, cutColor: cut),
    );
  }
}
