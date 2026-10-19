import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_name_layout.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Плашка названия (L4): пергамент внизу карты, сверху полоса цвета фракции.
///
/// Высота плашки — минимум из макета: если имя заняло две строки, плашка растёт вверх. Как именно ложится имя,
/// решает [CardNameLayout].
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
    final extra = switch (size) {
      CardSize.full => 4.0,
      CardSize.grid => 2.0,
      _ => 0.0,
    };
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
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ColoredBox(
              color: stripeColor,
              child: SizedBox(height: m.stripe),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: m.plaqueHeight, minWidth: double.infinity),
            child: Padding(
              padding: EdgeInsets.fromLTRB(m.plaquePaddingX, m.stripe + extra, m.plaquePaddingX, extra),
              child: Center(child: _name(CardNameLayout.of(name, size), m)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _name(CardNameLayout layout, CardMetrics m) => switch (layout) {
    SingleLineName(:final text, :final fontSize) => _text(text, _nameStyle(m, fontSize, 1.1), maxLines: 1),
    TwoLineName(:final text, :final fontSize) => _text(text, _nameStyle(m, fontSize, 1.08), maxLines: 2),
    SplitName(:final title, :final titleFontSize, :final subtitle, :final subtitleFontSize, :final gap) => Column(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [
        _text(title, _nameStyle(m, titleFontSize, 1.05), maxLines: 1),
        _text(
          subtitle,
          TextStyle(
            fontFamily: GwentText.alegreya,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            fontSize: subtitleFontSize,
            height: 1.15,
            color: GwentColors.onParchmentQuote,
          ),
          maxLines: 1,
        ),
      ],
    ),
  };

  static TextStyle _nameStyle(CardMetrics m, double fontSize, double height) => m.nameUsesTitleFont
      ? TextStyle(
          fontFamily: GwentText.cormorant,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
          height: height,
          letterSpacing: fontSize * 0.02,
          color: GwentColors.onParchment,
        )
      : TextStyle(
          fontFamily: GwentText.alegreya,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          height: height,
          color: GwentColors.onParchment,
        );

  static Widget _text(String text, TextStyle style, {required int maxLines}) => Text(
    text,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    textScaler: TextScaler.noScaling,
    style: style,
  );
}
