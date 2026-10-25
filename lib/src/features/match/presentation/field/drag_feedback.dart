import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Карта под пальцем при перетаскивании (макет 14): мини-карта и кольцо пальца.
///
/// Мини-карта стоит центром на [up] pt выше и на [aside] pt левее касания, а у левого края экрана переходит на
/// другую сторону от пальца, чтобы не уйти за экран; поэтому она не закрывает ряд под пальцем. Над целью карта
/// яркая, не над целью тусклая (55 %, без цвета): «ничего не горит — карта вернётся в руку». Палец (точка
/// привязки) лежит в центре виджета [size].
class DragFeedback extends StatelessWidget {
  /// Создаёт карту под пальцем; [over] — палец над целью, [pointer] — положение пальца на экране.
  const DragFeedback({super.key, required this.face, required this.over, required this.pointer});

  /// Сторона квадрата, в центре которого палец: места хватает мини-карте с любой стороны.
  static const double side = 160;

  /// Размер виджета.
  static const Size size = Size.square(side);

  /// Насколько центр мини-карты выше касания.
  static const double up = 44;

  /// Насколько центр мини-карты в стороне от касания.
  static const double aside = 28;

  /// Диаметр кольца пальца.
  static const double ringSize = 36;

  /// Прозрачность карты не над целью.
  static const double dimmedOpacity = 0.55;

  /// Отступ мини-карты от края экрана, при котором она переходит на другую сторону пальца.
  static const double edgeInset = 6;

  /// Смена яркости карты.
  static const Duration fade = Duration(milliseconds: 120);

  /// Лицо перетаскиваемой карты.
  final CardFace face;

  /// Палец над целью.
  final ValueListenable<bool> over;

  /// Положение пальца в координатах экрана; `null` до первого движения.
  final ValueListenable<Offset?> pointer;

  /// Центр мини-карты относительно касания при положении пальца [pointer].
  static Offset cardOffset(Offset? pointer) {
    final left = pointer == null || pointer.dx - aside - CardMetrics.mini.width / 2 >= edgeInset;
    return Offset(left ? -aside : aside, -up);
  }

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: size,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        ValueListenableBuilder<Offset?>(
          valueListenable: pointer,
          builder: (context, position, _) => Transform.translate(
            offset: cardOffset(position),
            child: ValueListenableBuilder<bool>(
              valueListenable: over,
              builder: (context, over, _) => AnimatedOpacity(
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : fade,
                opacity: over ? 1 : dimmedOpacity,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    boxShadow: [BoxShadow(color: Color(0x99000000), offset: Offset(0, 6), blurRadius: 10)],
                  ),
                  child: GwentCard(face: face, size: CardSize.mini),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: ringSize,
          height: ringSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GwentColors.textPrimary.withValues(alpha: 0.55), width: 1.5),
          ),
        ),
      ],
    ),
  );
}
