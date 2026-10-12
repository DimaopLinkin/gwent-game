import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Состояние счётчика колоды.
enum DeckCounterStatus {
  /// Норма.
  ok,

  /// Недобор: красная рамка, число и стрелка вниз, подпись «Нужно ещё N карт».
  shortfall,

  /// Достигнут максимум: золотая рамка.
  limit,
}

/// Счётчик колоды в конструкторе (макет дизайн-системы, `deckCounter`): иконка, подпись и «число/норма».
///
/// Недобор отмечен не только цветом: красной рамкой, стрелкой вниз и подписью с недостающим числом.
class DeckCounter extends StatelessWidget {
  /// Создаёт счётчик: [label] — подпись («Карты отрядов»), [count] из [target].
  const DeckCounter({
    super.key,
    required this.label,
    required this.count,
    required this.target,
    this.status = DeckCounterStatus.ok,
    this.icon = GwentIcon.iconDeck,
  });

  /// Подпись; при недоборе — текст про недостающие карты.
  final String label;

  /// Сколько карт сейчас.
  final int count;

  /// Сколько нужно или максимум.
  final int target;

  /// Состояние.
  final DeckCounterStatus status;

  /// Иконка слева.
  final GwentIcon icon;

  @override
  Widget build(BuildContext context) {
    final (border, numberColor, labelColor, labelSize) = switch (status) {
      DeckCounterStatus.ok => (GwentColors.line, GwentColors.textPrimary, GwentColors.textSecondary, 14.0),
      DeckCounterStatus.shortfall => (GwentColors.debuff, GwentColors.debuff, GwentColors.errorText, 13.0),
      DeckCounterStatus.limit => (GwentColors.gold, GwentColors.gold, GwentColors.textSecondary, 14.0),
    };
    return Semantics(
      label: '$label: $count/$target',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: GwentColors.surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(GwentSpace.radiusS),
        ),
        child: Row(
          spacing: 12,
          children: [
            GwentIconView(
              status == DeckCounterStatus.shortfall ? GwentIcon.iconPowerDown : icon,
              size: 20,
              color: status == DeckCounterStatus.shortfall ? GwentColors.debuff : GwentColors.textSecondary,
            ),
            Expanded(
              child: Text(
                label,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontWeight: FontWeight.w500,
                  fontSize: labelSize,
                  height: 1.2,
                  color: labelColor,
                ),
              ),
            ),
            Text.rich(
              TextSpan(
                text: '$count',
                children: [
                  TextSpan(
                    text: '/$target',
                    style: const TextStyle(color: GwentColors.textSecondary),
                  ),
                ],
              ),
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: GwentText.alegreya,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                height: 1,
                fontFeatures: GwentText.numbers,
                color: numberColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
