import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Затемнение поля при выборе цели (макет оверлеев, «Выбор цели на поле»): 66 % тёмного поверх зоны [area] с
/// вырезами вокруг целей.
///
/// Касания проходят сквозь затемнение: цели ловят нажатия и броски сами. Вырезы рисуются в координатах поля,
/// как и [area].
class TargetScrim extends StatelessWidget {
  /// Создаёт затемнение зоны [area] с вырезами [holes].
  const TargetScrim({super.key, required this.area, required this.holes});

  /// Затемнение.
  static const Color color = Color(0xA80A0806);

  /// Запас вокруг цели: свечение рамки не должно уходить под затемнение.
  static const double margin = 2;

  /// Зона затемнения в координатах поля.
  final Rect area;

  /// Прозрачные вырезы в координатах поля.
  final List<Rect> holes;

  @override
  Widget build(BuildContext context) => Positioned.fromRect(
    rect: area,
    child: IgnorePointer(
      child: CustomPaint(
        painter: _ScrimPainter([for (final hole in holes) hole.shift(-area.topLeft).inflate(margin)]),
      ),
    ),
  );
}

class _ScrimPainter extends CustomPainter {
  _ScrimPainter(this.holes);

  final List<Rect> holes;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()..addRect(Offset.zero & size);
    if (holes.isNotEmpty) {
      final cut = Path();
      for (final hole in holes) {
        cut.addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(6)));
      }
      path = Path.combine(PathOperation.difference, path, cut);
    }
    canvas.drawPath(path, Paint()..color = TargetScrim.color);
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) {
    if (oldDelegate.holes.length != holes.length) return true;
    for (var i = 0; i < holes.length; i++) {
      if (oldDelegate.holes[i] != holes[i]) return true;
    }
    return false;
  }
}

/// Полоса подсказки на месте полосы соперника (макет оверлеев): мини-карта, что нужно сделать и «Отмена».
///
/// Высота 48 pt, как у полосы игрока, поэтому поле не прыгает. Без [onCancel] кнопки нет: выбор, которого ждёт
/// движок, отменить нельзя.
class TargetHintBar extends StatelessWidget {
  /// Создаёт полосу подсказки.
  const TargetHintBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.face,
    this.cancelLabel,
    this.onCancel,
  });

  /// Высота полосы.
  static const double height = 48;

  /// Ширина кнопки отмены.
  static const double cancelWidth = 84;

  /// Высота кнопки отмены.
  static const double cancelHeight = 44;

  /// Мини-карта, которую играют; `null` — без карты.
  final CardFace? face;

  /// Что делать: «Выберите ряд».
  final String title;

  /// Пояснение.
  final String subtitle;

  /// Подпись кнопки отмены.
  final String? cancelLabel;

  /// Отмена; `null` — кнопки нет.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final face = this.face;
    final onCancel = this.onCancel;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $subtitle',
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241D14), Color(0xFF1B1612)],
          ),
          border: Border(bottom: BorderSide(color: GwentColors.gold, width: 1.5)),
        ),
        child: Row(
          spacing: 10,
          children: [
            if (face != null) GwentCard(face: face, size: CardSize.mini),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: GwentText.cormorant,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.05,
                      letterSpacing: 0.4,
                      color: GwentColors.goldHighlight,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                    style: GwentText.caption.copyWith(fontSize: 12.5, height: 1.1),
                  ),
                ],
              ),
            ),
            if (onCancel != null && cancelLabel != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCancel,
                child: Semantics(
                  button: true,
                  label: cancelLabel,
                  excludeSemantics: true,
                  onTap: onCancel,
                  child: SizedBox(
                    width: cancelWidth,
                    height: cancelHeight,
                    child: Center(
                      child: Container(
                        height: 34,
                        width: cancelWidth,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(color: GwentColors.brass),
                        ),
                        child: Text(
                          cancelLabel!,
                          textScaler: TextScaler.noScaling,
                          style: GwentText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14, height: 1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
