import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/components/button_sound_scope.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Круглая кнопка со стрелкой-шевроном: «назад» в шапке и стрелки карусели фракций. Зона нажатия 44×44 pt.
class ChevronButton extends StatelessWidget {
  /// Создаёт кнопку; без [onPressed] она погашена.
  const ChevronButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.forward = false,
    this.ring = GwentColors.muted,
  });

  /// Подпись для экранного диктора.
  final String label;

  /// Нажатие; `null` — кнопка погашена (треть яркости).
  final VoidCallback? onPressed;

  /// Стрелка вправо; иначе влево.
  final bool forward;

  /// Цвет кольца.
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final action = ButtonSoundScope.wrap(context, onPressed);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: action,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: action,
        child: Opacity(
          opacity: onPressed == null ? 0.3 : 1,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xEB14110E),
              border: Border.all(color: ring),
            ),
            child: CustomPaint(painter: _ChevronPainter(forward: forward)),
          ),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.forward});

  final bool forward;

  @override
  void paint(Canvas canvas, Size size) {
    // Шеврон из макета: 8 pt в ширину и 16 в высоту вокруг центра круга.
    final c = size.center(Offset.zero);
    final dx = forward ? -4.0 : 4.0;
    final path = Path()
      ..moveTo(c.dx + dx, c.dy - 8)
      ..lineTo(c.dx - dx, c.dy)
      ..lineTo(c.dx + dx, c.dy + 8);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = GwentColors.goldHighlight,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.forward != forward;
}
