import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Тень угла (L2): затемнение верхнего левого угла под медальонами (82 % → 50 % → 0 на 85×62 % карты), чтобы
/// сила и иконки читались на светлом и пёстром арте.
class CardCornerShade extends StatelessWidget {
  /// Создаёт тень угла.
  const CardCornerShade({super.key});

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.topLeft,
    child: FractionallySizedBox(
      widthFactor: 0.85,
      heightFactor: 0.62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1,
            colors: [Color(0xD10A0806), Color(0x800A0806), Color(0x000A0806)],
            stops: [0, 0.4, 0.78],
          ),
        ),
      ),
    ),
  );
}

/// Подсветка арта цветом погоды на карте погоды.
class CardWeatherWash extends StatelessWidget {
  /// Создаёт подсветку цвета [tint].
  const CardWeatherWash({super.key, required this.tint});

  /// Цвет погоды.
  final Color tint;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -0.4),
        radius: 0.9,
        colors: [tint.withValues(alpha: 0.28), tint.withValues(alpha: 0)],
        stops: const [0, 0.7],
      ),
    ),
  );
}

/// Иней на арте отряда под погодой (L3). У героя не рисуется: так видно, что погода на него не действует.
class CardFrostLayer extends StatelessWidget {
  /// Создаёт иней со свечением [glow].
  const CardFrostLayer({super.key, required this.glow});

  /// Радиус внутреннего свечения по краю.
  final double glow;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _FrostPainter(glow), child: const SizedBox.expand());
}

class _FrostPainter extends CustomPainter {
  const _FrostPainter(this.glow);

  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas
      ..drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              GwentColors.frostTint.withValues(alpha: 0.42),
              GwentColors.frostTint.withValues(alpha: 0.14),
              GwentColors.frostTint.withValues(alpha: 0.34),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(rect),
      )
      ..save()
      ..clipRect(rect)
      ..drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = glow
          ..color = const Color(0xB3D2E6F5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow / 2),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_FrostPainter oldDelegate) => oldDelegate.glow != glow;
}
