import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_content_mapper.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/diamond_marker.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_state.dart';
import 'package:gwent/src/features/deck_builder/presentation/editor/editor_filters.dart';

/// Сетка карт открытой вкладки (макеты 8 и 15): три колонки карт 103×148 со счётчиком «N из M» или «× N», карты
/// сверху вниз от сильных к слабым по группам «Герои», «Отряды», «Особые» (`CollectionOrder`).
///
/// Тап перемещает карту между коллекцией и колодой, долгое нажатие открывает просмотр. Карты, которые сейчас нельзя
/// добавить, приглушены. Если под фильтр ничего не попало, вместо сетки пустое состояние с пояснением.
class EditorGrid extends StatelessWidget {
  /// Создаёт сетку для состояния [state].
  const EditorGrid({
    super.key,
    required this.state,
    required this.mapper,
    required this.onTapCard,
    required this.onLongPressCard,
    this.shrinkWrap = false,
  });

  /// Состояние конструктора.
  final DeckEditorReady state;

  /// Сопоставление карт пакета с видом карты.
  final CardContentMapper mapper;

  /// Тап по карте с UUID.
  final ValueChanged<String> onTapCard;

  /// Долгое нажатие на карту с UUID.
  final ValueChanged<String> onLongPressCard;

  /// Сетка занимает ровно столько высоты, сколько нужно картам, и не прокручивается сама: её прокручивает экран.
  final bool shrinkWrap;

  static const double _cardWidth = 103;
  static const double _cardHeight = 148;
  static const double _columnGap = 16;

  @override
  Widget build(BuildContext context) {
    final groups = state.visibleGroups;
    if (groups.isEmpty) return _EmptyGrid(state: state);
    final inCollection = state.tab == DeckEditorTab.collection;
    final labelled = groups.length > 1;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _cardWidth * 3 + _columnGap * 2),
        child: CustomScrollView(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 6)),
            for (final (index, group) in groups.indexed) ...[
              if (labelled)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 14, bottom: 14),
                    child: _GroupLabel(group: group.group, count: group.cards.length),
                  ),
                ),
              SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: _columnGap,
                  mainAxisSpacing: 14,
                  childAspectRatio: _cardWidth / _cardHeight,
                ),
                itemCount: group.cards.length,
                itemBuilder: (context, index) => _card(context, group.cards[index], inCollection: inCollection),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, EditorCard entry, {required bool inCollection}) {
    final detail = mapper.byId(entry.card.id);
    if (detail == null) return const SizedBox.shrink();
    final id = entry.card.id;
    return _Pop(
      key: ValueKey(id),
      serial: state.lastMoved == id ? state.moveSerial : 0,
      child: FittedBox(
        child: SizedBox(
          width: _cardWidth,
          height: _cardHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GwentCard(
                face: detail.face,
                size: CardSize.grid,
                highlight: inCollection && entry.blocked ? CardHighlight.disabled : CardHighlight.normal,
                onTap: () => onTapCard(id),
                onLongPress: () => onLongPressCard(id),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: IgnorePointer(
                  child: _CopiesPill(
                    text: entry.locked
                        ? context.l10n.editorCopiesLocked
                        : inCollection
                        ? context.l10n.editorCopiesOf(entry.copies, entry.limit)
                        : context.l10n.editorCopiesIn(entry.copies),
                    full: !entry.locked && entry.copies >= entry.limit,
                    empty: entry.copies == 0,
                  ),
                ),
              ),
              if (entry.card.isNeutral)
                const Positioned(right: 9, top: 27, child: DiamondMarker(size: 8, color: GwentColors.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Метка группы карт: ромб, название и число карт, линия до края сетки. Не нажимается.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.group, required this.count});

  final CollectionGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = switch (group) {
      CollectionGroup.heroes => l10n.editorGroupHeroes,
      CollectionGroup.units => l10n.editorGroupUnits,
      CollectionGroup.specials => l10n.editorGroupSpecials,
    };
    return SizedBox(
      height: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          spacing: 8,
          children: [
            const DiamondMarker(size: 7, color: GwentColors.brass),
            Text(
              name.toUpperCase(),
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.cormorant,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 2.1,
                height: 1,
                color: GwentColors.textSecondary,
              ),
            ),
            Text(
              '$count',
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.alegreya,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1,
                fontFeatures: GwentText.numbers,
                color: GwentColors.muted,
              ),
            ),
            const Expanded(
              child: SizedBox(height: 1, child: ColoredBox(color: GwentColors.line)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopiesPill extends StatelessWidget {
  const _CopiesPill({required this.text, required this.full, required this.empty});

  final String text;
  final bool full;
  final bool empty;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: full
          ? GwentColors.gold
          : empty
          ? GwentColors.surfaceRaised
          : GwentColors.bg,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: GwentColors.bg),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: 16,
        child: Center(
          child: Text(
            text,
            maxLines: 1,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: GwentText.alegreya,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              height: 1,
              fontFeatures: GwentText.numbers,
              color: full
                  ? GwentColors.onGold
                  : empty
                  ? GwentColors.textSecondary
                  : GwentColors.goldHighlight,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Короткий «хлопок» карты, которую только что переместили: от 0,86 до натурального размера за 350 мс.
///
/// Анимация запускается, когда [serial] меняется и не равен нулю.
class _Pop extends StatelessWidget {
  const _Pop({super.key, required this.serial, required this.child});

  final int serial;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (serial == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(serial),
      tween: Tween(begin: 0.86, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

class _EmptyGrid extends StatelessWidget {
  const _EmptyGrid({required this.state});

  final DeckEditorReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filter = cardFilterLabel(l10n, state.filter);
    final collection = state.tab == DeckEditorTab.collection;
    final (title, text) = switch ((collection, state.onlyAvailable)) {
      (true, true) => (l10n.editorEmptyAvailableTitle, l10n.editorEmptyAvailableText(filter)),
      (true, false) => (l10n.editorEmptyTitle, l10n.editorEmptyText(filter)),
      (false, _) => (l10n.editorEmptyDeckTitle, l10n.editorEmptyDeckText(filter)),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GwentColors.rowSurface,
                border: Border.all(color: GwentColors.line),
              ),
              child: SizedBox.square(
                dimension: 56,
                child: Center(
                  child: GwentIconView(
                    collection ? GwentIcon.iconDeck : GwentIcon.weatherFrost,
                    size: 30,
                    color: GwentColors.muted,
                  ),
                ),
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.cormorant,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                height: 1.1,
                color: GwentColors.textPrimary,
              ),
            ),
            Text(
              text,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.alegreya,
                fontSize: 16,
                height: 1.35,
                color: GwentColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
