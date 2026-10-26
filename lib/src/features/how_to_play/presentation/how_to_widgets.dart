import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Основной текст справочника: Alegreya 17, растёт вместе с системным шрифтом.
const TextStyle howToBodyStyle = TextStyle(
  fontFamily: GwentText.alegreya,
  fontSize: 17,
  height: 1.4,
  color: GwentColors.textPrimary,
);

/// Золотая монета-иконка в латунном диске: так же рисуются способности на картах.
class HowToCoin extends StatelessWidget {
  /// Создаёт монету стороной [size] с иконкой [icon].
  const HowToCoin(this.icon, {super.key, this.size = 44});

  /// Иконка на монете.
  final GwentIcon icon;

  /// Сторона монеты.
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.2, -0.36),
          radius: 0.9,
          colors: [Color(0xFFD3B06A), GwentColors.brassLight, GwentColors.brassDark],
          stops: [0, 0.58, 1],
        ),
        boxShadow: [BoxShadow(color: GwentColors.brassDeep, spreadRadius: 1)],
      ),
      child: Center(
        child: GwentIconView(icon, size: size * 0.55, color: GwentColors.onGold, cutColor: GwentColors.brassCut),
      ),
    ),
  );
}

/// Блок «Запомните»: главная мысль темы в золотой рамке.
class HowToRemember extends StatelessWidget {
  /// Создаёт блок с подписью [label] и текстом [text].
  const HowToRemember({super.key, required this.label, required this.text});

  /// Подпись блока.
  final String label;

  /// Главная мысль.
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: GwentColors.goldSurface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: GwentColors.gold),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.15,
              letterSpacing: 15 * 0.12,
              color: GwentColors.goldHighlight,
            ),
          ),
          Text(text, style: howToBodyStyle.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}
