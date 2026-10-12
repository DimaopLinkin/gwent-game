import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_detail.dart';
import 'package:gwent/src/core/presentation/card/parts/card_coin.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Пергамент полного просмотра: название (и титул после двоеточия), строка «фракция · ряд · тип», способности и
/// цитата. Если не помещается по высоте, прокручивается.
class CardDetailPlaque extends StatelessWidget {
  /// Создаёт пергамент для [detail].
  const CardDetailPlaque({super.key, required this.detail});

  /// Карта и описание.
  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    final name = detail.face.name;
    final colon = name.indexOf(': ');
    final title = colon > 0 ? name.substring(0, colon) : name;
    final subtitle = colon > 0 ? name.substring(colon + 2) : null;
    final quote = detail.quote;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GwentColors.parchmentLight, GwentColors.parchmentShade],
        ),
        borderRadius: BorderRadius.circular(GwentSpace.radiusS),
        border: Border.all(color: GwentColors.brass),
        boxShadow: const [BoxShadow(color: Color(0x99080502), offset: Offset(0, 10), blurRadius: 28)],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Column(
              spacing: 4,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                    height: 1.1,
                    color: GwentColors.onParchment,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      height: 1.25,
                      color: GwentColors.onParchmentQuote,
                    ),
                  ),
                Text(
                  detail.meta,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1.3,
                    color: GwentColors.onParchmentSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0x008C6A3F), GwentColors.brass, Color(0x008C6A3F)]),
                ),
              ),
            ),
            for (final ability in detail.abilities) _AbilityRow(ability),
            if (quote != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  spacing: 10,
                  children: [
                    const _Diamond(),
                    Expanded(
                      child: Text(
                        quote,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: GwentText.alegreya,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                          height: 1.45,
                          color: GwentColors.onParchmentQuote,
                        ),
                      ),
                    ),
                    const _Diamond(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AbilityRow extends StatelessWidget {
  const _AbilityRow(this.ability);

  final CardAbilityLine ability;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      CardCoin.effect(
        icon: ability.icon,
        diameter: 30,
        iconSize: 18,
        rings: const [BoxShadow(color: GwentColors.brassDeep, spreadRadius: 1)],
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 3,
          children: [
            Text(
              ability.name,
              style: const TextStyle(
                fontFamily: GwentText.alegreya,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.2,
                color: GwentColors.onParchment,
              ),
            ),
            Text(
              ability.description,
              style: const TextStyle(
                fontFamily: GwentText.alegreya,
                fontSize: 14.5,
                height: 1.4,
                color: GwentColors.onParchment,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Diamond extends StatelessWidget {
  const _Diamond();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.785398,
    child: const SizedBox.square(dimension: 5, child: ColoredBox(color: GwentColors.brass)),
  );
}
