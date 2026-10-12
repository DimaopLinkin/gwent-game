import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Плашка названия (L4): пергамент внизу карты, сверху полоса цвета фракции.
///
/// В полном просмотре и в сетке длинное имя переносится на вторую строку, и плашка растёт вверх; на руке имя
/// остаётся в одну строку с многоточием.
class CardPlaque extends StatelessWidget {
  /// Создаёт плашку с названием [name].
  const CardPlaque({super.key, required this.name, required this.stripeColor, required this.size});

  /// Название карты.
  final String name;

  /// Цвет полосы: фракция, у погоды — цвет погоды.
  final Color stripeColor;

  /// Размер карты.
  final CardSize size;

  @override
  Widget build(BuildContext context) {
    final m = size.metrics;
    final style = m.nameUsesTitleFont
        ? TextStyle(
            fontFamily: GwentText.cormorant,
            fontWeight: FontWeight.w600,
            fontSize: m.nameFontSize,
            height: 1.1,
            letterSpacing: m.nameFontSize * 0.02,
            color: GwentColors.onParchment,
          )
        : TextStyle(
            fontFamily: GwentText.alegreya,
            fontWeight: FontWeight.w700,
            fontSize: m.nameFontSize,
            height: 1.1,
            color: GwentColors.onParchment,
          );
    final bottom = Radius.circular(m.innerRadius);
    return Container(
      constraints: BoxConstraints(minHeight: m.plaqueHeight),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GwentColors.parchmentLight, GwentColors.parchmentDark],
        ),
        borderRadius: BorderRadius.only(bottomLeft: bottom, bottomRight: bottom),
        boxShadow: const [BoxShadow(color: GwentColors.brass, offset: Offset(0, -1))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: stripeColor,
            child: SizedBox(height: m.stripe),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: m.plaqueHeight - m.stripe),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: m.plaquePaddingX, vertical: m.stripe),
              child: Center(
                child: Text(
                  name,
                  maxLines: size.wrapsName ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: style,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
