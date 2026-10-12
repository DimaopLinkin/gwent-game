import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Стопка карт на панели игрока (макет поля): мини-карта 31×44 с числом карт в пилюле у нижнего края.
///
/// Колода показывает рубашку, сброс — верхнюю карту или пустой пунктирный слот. Тап по сбросу открывает его лист.
class CardPile extends StatelessWidget {
  /// Создаёт стопку из [count] карт; [top] — верхняя карта (рубашка колоды или последняя карта сброса).
  const CardPile({super.key, required this.top, required this.count, this.semanticsLabel, this.onTap});

  /// Ширина.
  static const double width = 31;

  /// Высота.
  static const double height = 44;

  /// Верхняя карта; `null` у пустого сброса.
  final CardFace? top;

  /// Сколько карт в стопке.
  final int count;

  /// Подпись для экранного диктора.
  final String? semanticsLabel;

  /// Тап по стопке.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final top = this.top;
    final pile = SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: top == null
                ? const _EmptySlot()
                : ExcludeSemantics(
                    child: GwentCard(face: top, size: CardSize.mini),
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 2,
            child: Center(child: _CountPill(count: count)),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      onTap: onTap,
      child: onTap == null ? pile : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: pile),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: GwentColors.gold.withValues(alpha: 0.4)),
    ),
    child: const Center(
      child: GwentIconView(GwentIcon.iconDiscard, size: 14, color: Color(0x80A99B80)),
    ),
  );
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 20),
    height: 15,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: GwentColors.bg,
      borderRadius: BorderRadius.circular(999),
      boxShadow: const [BoxShadow(color: GwentColors.brass, spreadRadius: 1)],
    ),
    child: Text(
      '$count',
      textScaler: TextScaler.noScaling,
      style: GwentText.powerCard.copyWith(fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}
