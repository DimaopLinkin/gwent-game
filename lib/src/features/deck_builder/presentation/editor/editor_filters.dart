import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/diamond_marker.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_state.dart';

/// Подпись фильтра [filter] для интерфейса.
String cardFilterLabel(AppLocalizations l10n, CardFilter filter) => switch (filter) {
  CardFilter.all => l10n.editorFilterAll,
  CardFilter.melee => l10n.editorFilterMelee,
  CardFilter.ranged => l10n.editorFilterRanged,
  CardFilter.siege => l10n.editorFilterSiege,
  CardFilter.hero => l10n.editorFilterHero,
  CardFilter.weather => l10n.editorFilterWeather,
  CardFilter.special => l10n.editorFilterSpecial,
};

GwentIcon _filterIcon(CardFilter filter) => switch (filter) {
  CardFilter.all => GwentIcon.iconDeck,
  CardFilter.melee => GwentIcon.rowMelee,
  CardFilter.ranged => GwentIcon.rowRanged,
  CardFilter.siege => GwentIcon.rowSiege,
  CardFilter.hero => GwentIcon.iconLeader,
  CardFilter.weather => GwentIcon.weatherFrost,
  CardFilter.special => GwentIcon.abilityCommanderHorn,
};

/// Две вкладки конструктора: «Коллекция N» (сколько карт можно добавить) и «Колода N» (сколько карт в колоде).
class EditorTabs extends StatelessWidget {
  /// Создаёт вкладки для состояния [state].
  const EditorTabs({super.key, required this.state, required this.onSelected});

  /// Состояние конструктора.
  final DeckEditorReady state;

  /// Игрок выбрал вкладку.
  final ValueChanged<DeckEditorTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      spacing: 6,
      children: [
        _TabPill(
          label: l10n.editorTabCollection,
          count: state.availableCount,
          selected: state.tab == DeckEditorTab.collection,
          onTap: () => onSelected(DeckEditorTab.collection),
        ),
        _TabPill(
          label: l10n.editorTabDeck,
          count: state.stats.total,
          selected: state.tab == DeckEditorTab.deck,
          onTap: () => onSelected(DeckEditorTab.deck),
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      label: label,
      value: '$count',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? const RadialGradient(
                    center: Alignment(0, -0.4),
                    radius: 1.1,
                    colors: [GwentColors.surfaceWarm, GwentColors.surface],
                    stops: [0, 0.7],
                  )
                : null,
            color: selected ? null : GwentColors.rowSurface,
            border: Border.all(color: selected ? GwentColors.gold : GwentColors.line, width: selected ? 1.5 : 1),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontSize: 17,
                    letterSpacing: 17 * 0.04,
                    color: selected ? GwentColors.textPrimary : GwentColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: '$count',
                  style: TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontSize: 15,
                    fontFeatures: GwentText.numbers,
                    color: selected ? GwentColors.goldHighlight : GwentColors.muted,
                  ),
                ),
              ],
            ),
            textScaler: TextScaler.noScaling,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1),
          ),
        ),
      ),
    ),
  );
}

/// Ряд фильтров с иконками: все, ближний, дальний, осадные, герои, погода, особые.
class EditorFilters extends StatelessWidget {
  /// Создаёт ряд для состояния [state].
  const EditorFilters({super.key, required this.state, required this.onSelected});

  /// Состояние конструктора.
  final DeckEditorReady state;

  /// Игрок выбрал фильтр.
  final ValueChanged<CardFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        for (final filter in CardFilter.values)
          Expanded(
            child: _FilterCell(
              label: cardFilterLabel(l10n, filter),
              icon: _filterIcon(filter),
              selected: filter == state.filter,
              onTap: () => onSelected(filter),
            ),
          ),
      ],
    );
  }
}

class _FilterCell extends StatelessWidget {
  const _FilterCell({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final GwentIcon icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? GwentColors.goldHighlight : GwentColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: selected ? GwentColors.rowSelected : null,
            borderRadius: BorderRadius.circular(5),
            border: selected ? Border.all(color: GwentColors.gold) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 3,
            children: [
              GwentIconView(icon, size: 20, color: color),
              // Подпись уменьшается, а не обрезается: на узком экране «Ближний» иначе не помещается в седьмую часть ряда.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка под фильтрами: пометка «общая карта» и, на вкладке «Коллекция», переключатель «Только доступные».
class EditorLegend extends StatelessWidget {
  /// Создаёт строку для состояния [state].
  const EditorLegend({super.key, required this.state, required this.onToggleAvailable});

  /// Состояние конструктора.
  final DeckEditorReady state;

  /// Игрок переключил «Только доступные».
  final VoidCallback onToggleAvailable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final on = state.onlyAvailable;
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            spacing: 6,
            children: [
              const DiamondMarker(size: 7, color: GwentColors.textTertiary),
              Text(
                l10n.editorNeutralLegend,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  height: 1,
                  color: GwentColors.textSecondary,
                ),
              ),
            ],
          ),
          if (state.tab == DeckEditorTab.collection)
            Semantics(
              button: true,
              toggled: on,
              label: l10n.editorOnlyAvailable,
              onTap: onToggleAvailable,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleAvailable,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: on ? GwentColors.goldSurface : null,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: on ? GwentColors.gold : GwentColors.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                      child: Row(
                        spacing: 7,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DiamondMarker(size: 8, color: on ? GwentColors.gold : GwentColors.bg),
                          Text(
                            l10n.editorOnlyAvailable,
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              fontFamily: GwentText.alegreya,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              height: 1,
                              color: on ? GwentColors.goldHighlight : GwentColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
