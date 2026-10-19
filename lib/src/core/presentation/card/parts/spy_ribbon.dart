import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';

/// Лента шпиона с глазом (L7): мой шпион на поле соперника, цвет — фракция владельца.
class SpyRibbon extends StatelessWidget {
  /// Создаёт ленту шириной [width].
  const SpyRibbon({super.key, required this.width, required this.color});

  /// Ширина ленты.
  final double width;

  /// Цвет владельца.
  final Color color;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const _RibbonClipper(),
    child: Container(
      width: width,
      height: (width * 1.35).roundToDouble(),
      color: color,
      alignment: Alignment.topCenter,
      padding: EdgeInsets.only(top: (width * 0.14).roundToDouble()),
      child: GwentIconView(
        GwentIcon.abilitySpy,
        size: (width * 0.62).roundToDouble(),
        color: GwentColors.textPrimary,
        cutColor: color,
      ),
    ),
  );
}

/// Ласточкин хвост снизу: вырез до 78 % высоты по центру.
class _RibbonClipper extends CustomClipper<Path> {
  const _RibbonClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(size.width / 2, size.height * 0.78)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_RibbonClipper oldClipper) => false;
}
