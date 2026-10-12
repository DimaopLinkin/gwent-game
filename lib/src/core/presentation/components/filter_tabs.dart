import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Одна вкладка фильтра.
final class FilterTabData {
  /// Создаёт вкладку: [label] и [count] показываются, [icon] слева.
  const FilterTabData({required this.label, required this.icon, this.count});

  /// Название.
  final String label;

  /// Иконка 16 pt.
  final GwentIcon icon;

  /// Сколько карт; `null` — число не показывается; 0 — вкладка недоступна.
  final int? count;
}

/// Вкладки-фильтры (макет дизайн-системы, `filterTabs`): ряд вкладок 44 pt с нижней чертой; выбранная — золотая,
/// недоступная (карт 0) — приглушённая. Ряд прокручивается по горизонтали, если вкладки не помещаются.
class FilterTabs extends StatelessWidget {
  /// Создаёт ряд вкладок.
  const FilterTabs({super.key, required this.tabs, required this.selectedIndex, required this.onSelected});

  /// Вкладки по порядку.
  final List<FilterTabData> tabs;

  /// Номер выбранной вкладки.
  final int selectedIndex;

  /// Выбрана вкладка с номером.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: GwentColors.line)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 2,
        children: [
          for (final (index, tab) in tabs.indexed)
            _FilterTab(
              tab: tab,
              selected: index == selectedIndex,
              onTap: tab.count == 0 ? null : () => onSelected(index),
            ),
        ],
      ),
    ),
  );
}

class _FilterTab extends StatefulWidget {
  const _FilterTab({required this.tab, required this.selected, required this.onTap});

  final FilterTabData tab;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_FilterTab> createState() => _FilterTabState();
}

class _FilterTabState extends State<_FilterTab> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final enabled = widget.onTap != null;
    final selected = widget.selected;
    final color = !enabled
        ? GwentColors.disabledIcon
        : selected
        ? GwentColors.gold
        : _pressed
        ? GwentColors.textPrimary
        : GwentColors.textSecondary;
    final count = tab.count;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: count == null ? tab.label : context.l10n.filterTabCount(tab.label, count),
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Focus(
        canRequestFocus: enabled,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = enabled),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: Container(
            height: GwentSpace.minTapTarget,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            foregroundDecoration: _focused
                ? BoxDecoration(
                    border: Border.all(color: GwentColors.focusRing, width: GwentSpace.focusRingWidth),
                    borderRadius: BorderRadius.circular(3),
                  )
                : null,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0x14C8A35B)
                  : _pressed
                  ? const Color(0x0FE8DCC2)
                  : null,
              border: Border(
                bottom: BorderSide(
                  color: selected
                      ? GwentColors.gold
                      : _pressed
                      ? GwentColors.line
                      : const Color(0x00000000),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 7,
              children: [
                GwentIconView(tab.icon, size: 16, color: color),
                Text(
                  tab.label,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1,
                    letterSpacing: 0.64,
                    color: color,
                  ),
                ),
                if (count != null)
                  Opacity(
                    opacity: 0.8,
                    child: Text(
                      '$count',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: GwentText.alegreya,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        height: 1,
                        fontFeatures: GwentText.numbers,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
