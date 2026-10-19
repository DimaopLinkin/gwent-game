import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Слой арта (L1): картинка 309×444 на всю карту под рамкой, `cover`, на малых размерах обрезается по центру
/// сверху (50 % 20 %). Без арта или при ошибке загрузки рисуется полосатая заглушка.
class CardArtLayer extends StatelessWidget {
  /// Создаёт слой арта шириной [cardWidth].
  const CardArtLayer({super.key, required this.art, required this.cardWidth});

  /// Арт; `null` — заглушка.
  final ImageProvider? art;

  /// Ширина карты: от неё зависит шаг полос заглушки.
  final double cardWidth;

  /// Точка кадрирования: по центру и на 20 % сверху, как `background-position: 50% 20%`.
  static const Alignment focus = Alignment(0, -0.6);

  @override
  Widget build(BuildContext context) {
    final placeholder = CustomPaint(painter: _StripesPainter(cardWidth), child: const SizedBox.expand());
    final image = art;
    if (image == null) return placeholder;
    return Image(
      image: image,
      fit: BoxFit.cover,
      alignment: focus,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

/// Диагональные полосы заглушки под 135°.
class _StripesPainter extends CustomPainter {
  _StripesPainter(double cardWidth) : _step = (cardWidth / 40).roundToDouble().clamp(2, double.infinity);

  final double _step;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = GwentColors.artPlaceholder);
    final stripe = Paint()
      ..color = GwentColors.artPlaceholderStripe
      ..strokeWidth = _step / 1.414;
    for (var x = -size.height; x < size.width; x += _step * 2 * 1.414) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), stripe);
    }
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) => oldDelegate._step != _step;
}
