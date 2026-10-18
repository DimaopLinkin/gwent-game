import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Ромб-метка (выбранная колода, цвет фракции): квадрат, повёрнутый на 45°, с тёмным кантом.
class DiamondMarker extends StatelessWidget {
  /// Создаёт ромб со стороной [size].
  const DiamondMarker({super.key, required this.size, required this.color, this.glow});

  /// Сторона квадрата до поворота.
  final double size;

  /// Заливка.
  final Color color;

  /// Цвет свечения вокруг ромба или `null`.
  final Color? glow;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: math.pi / 4,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        boxShadow: [
          const BoxShadow(color: GwentColors.bg, spreadRadius: 1),
          if (glow != null) BoxShadow(color: glow!, blurRadius: 10),
        ],
      ),
      child: SizedBox.square(dimension: size),
    ),
  );
}
