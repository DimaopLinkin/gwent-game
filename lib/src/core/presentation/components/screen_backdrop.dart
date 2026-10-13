import 'package:flutter/widgets.dart';

/// Фон экранов выбора фракции, лидера, колоды и конструктора (макеты 7 и 8): тёмное дерево стола с едва заметными
/// горизонтальными полосами и виньеткой по краям. Содержимое [child] ложится поверх.
class ScreenBackdrop extends StatelessWidget {
  /// Создаёт фон.
  const ScreenBackdrop({super.key, required this.child});

  /// Содержимое экрана.
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1D12), Color(0xFF1A120B), Color(0xFF120C07)],
            stops: [0, 0.6, 1],
          ),
        ),
      ),
      const IgnorePointer(
        child: CustomPaint(painter: _StripesPainter(), size: Size.infinite),
      ),
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.2),
              radius: 1.15,
              colors: [Color(0x00050302), Color(0x00050302), Color(0xD9050302)],
              stops: [0, 0.3, 1],
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

/// Рисует полосы: 3 pt светлого тёплого тона и 4 pt тёмного через каждые 7 pt.
class _StripesPainter extends CustomPainter {
  const _StripesPainter();

  static const double _period = 7;
  static const double _light = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0x06FFE1AA);
    final dark = Paint()..color = const Color(0x0D000000);
    for (var y = 0.0; y < size.height; y += _period) {
      canvas
        ..drawRect(Rect.fromLTWH(0, y, size.width, _light), light)
        ..drawRect(Rect.fromLTWH(0, y + _light, size.width, _period - _light), dark);
    }
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) => false;
}
