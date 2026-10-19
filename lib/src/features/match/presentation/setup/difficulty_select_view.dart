import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/diamond_marker.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/setup/bot_difficulty_text.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;

/// Выбор сложности бота перед партией против него (ADR 0021): четыре уровня с описанием, выбранный выделен рамкой.
///
/// Отдельного макета нет: экран собран из деталей экрана выбора колоды (макет 7) — строки той же рамки и той же шапки.
class DifficultySelectView extends StatelessWidget {
  /// Создаёт экран.
  const DifficultySelectView({
    super.key,
    required this.eyebrow,
    required this.selected,
    required this.onSelect,
    required this.onConfirm,
    required this.onBack,
    this.busy = false,
  });

  /// Надпись над заголовком, например «Шаг 1 из 3».
  final String eyebrow;

  /// Выбранный уровень.
  final BotDifficulty selected;

  /// Игрок выбрал уровень `difficulty`.
  final ValueChanged<BotDifficulty> onSelect;

  /// Игрок подтвердил выбранный уровень.
  final VoidCallback onConfirm;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  /// Идёт сохранение выбора: кнопка не принимает нажатий.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: Column(
        children: [
          ScreenHeader(eyebrow: eyebrow, title: l10n.difficultySelectTitle, titleSize: 34, onBack: onBack),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      itemCount: BotDifficulty.values.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _DifficultyRow(
                        difficulty: BotDifficulty.values[i],
                        selected: BotDifficulty.values[i] == selected,
                        onTap: () => onSelect(BotDifficulty.values[i]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: GwentButton(label: l10n.difficultySelectConfirm, onPressed: busy ? null : onConfirm),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({required this.difficulty, required this.selected, required this.onTap});

  final BotDifficulty difficulty;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = botDifficultyName(l10n, difficulty);
    final description = botDifficultyDescription(l10n, difficulty);
    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  name,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    height: 1.05,
                    color: GwentColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    height: 1.3,
                    color: GwentColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (selected) const DiamondMarker(size: 12, color: GwentColors.goldHighlight, glow: Color(0xB3C8A35B)),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      value: description,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? GwentColors.rowSelected : GwentColors.rowSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? GwentColors.gold : GwentColors.line, width: selected ? 1.5 : 1),
          ),
          child: selected
              ? Padding(
                  padding: const EdgeInsets.all(2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: GwentColors.brass),
                    ),
                    child: content,
                  ),
                )
              : content,
        ),
      ),
    );
  }
}
