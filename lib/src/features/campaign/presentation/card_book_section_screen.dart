import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_content_mapper.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/components/status_tag.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/campaign/application/load_card_book.dart';
import 'package:gwent/src/features/campaign/domain/card_book.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_texts.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_widgets.dart';
import 'package:gwent/src/features/campaign/presentation/card_book_cubit.dart';
import 'package:gwent/src/features/campaign/presentation/card_book_screen.dart';
import 'package:gwent/src/features/campaign/presentation/card_book_state.dart';

/// «Книга карт», раздел: вкладки «Отряды / Особые / Лидеры», открытые карты с числом копий и силуэты закрытых.
/// Силуэт называет только вид карты: ни имени, ни подсказки, за какой узел она дастся.
///
/// Ждёт `CardBookCubit` выше по дереву.
class CardBookSectionScreen extends StatelessWidget {
  /// Создаёт экран раздела [sectionId] (`BookSection.id`).
  const CardBookSectionScreen({super.key, required this.sectionId, required this.onBack});

  /// Раздел книги.
  final String sectionId;

  /// Назад к обзору.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => BlocBuilder<CardBookCubit, CardBookState>(
    builder: (context, state) {
      final l10n = context.l10n;
      final section = state is CardBookReady ? state.loaded.book.section(sectionId) : null;
      return ScreenBackdrop(
        child: Column(
          children: [
            ScreenHeader(
              title: state is CardBookReady && section != null
                  ? bookSectionName(context, state.loaded, section)
                  : l10n.campaignBookTitle,
              onBack: onBack,
            ),
            Expanded(
              child: switch (state) {
                CardBookLoading() => const GameLoader(),
                CardBookUnavailable() => Center(child: Text(l10n.campaignBookUnavailable)),
                CardBookReady(:final loaded) =>
                  section == null
                      ? Center(child: Text(l10n.campaignBookUnavailable))
                      : _Section(loaded: loaded, section: section),
              },
            ),
          ],
        ),
      );
    },
  );
}

enum _Tab { squads, specials, leaders }

class _Section extends StatefulWidget {
  const _Section({required this.loaded, required this.section});

  final LoadedCardBook loaded;
  final BookSection section;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late _Tab _tab = _firstWithCards;

  /// Первая вкладка, на которой есть карты: у общих карт нет лидеров, у фракции без особых нет второй вкладки.
  _Tab get _firstWithCards => widget.section.squads.isNotEmpty ? _Tab.squads : _Tab.specials;

  List<BookCard> _cards(_Tab tab) => switch (tab) {
    _Tab.squads => widget.section.squads,
    _Tab.specials => widget.section.specials,
    _Tab.leaders => widget.section.leaders,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final section = widget.section;
    final tabs = [
      for (final tab in _Tab.values)
        if (_cards(tab).isNotEmpty) tab,
    ];
    final tab = tabs.contains(_tab) ? _tab : (tabs.firstOrNull ?? _Tab.squads);
    final cards = _cards(tab);
    String label(_Tab tab) => switch (tab) {
      _Tab.squads => l10n.campaignBookTabSquads,
      _Tab.specials => l10n.campaignBookTabSpecials,
      _Tab.leaders => l10n.campaignBookTabLeaders,
    };
    String count(int opened, int total) => l10n.campaignBookRowCount(opened, total);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            spacing: 10,
            children: [
              StatusTag(
                l10n.campaignBookFraction(section.opened, section.total),
                background: GwentColors.goldSurface,
                color: GwentColors.gold,
              ),
              Expanded(
                child: Text(
                  l10n.campaignBookSummary(
                    count(section.openedLeaders, section.totalLeaders),
                    count(section.openedSquads, section.totalSquads),
                    count(section.openedSpecials, section.totalSpecials),
                  ),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontSize: 13,
                    color: GwentColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        _Tabs(
          tabs: [for (final t in tabs) (label: label(t), selected: t == tab, onTap: () => setState(() => _tab = t))],
        ),
        Expanded(
          child: cards.isEmpty
              ? Center(child: Text(l10n.campaignBookEmptyTab))
              : _Grid(loaded: widget.loaded, cards: cards),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tabs});

  final List<({String label, bool selected, VoidCallback onTap})> tabs;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: GwentColors.line)),
    ),
    child: Row(
      children: [
        for (final tab in tabs)
          Expanded(
            child: Semantics(
              button: true,
              selected: tab.selected,
              label: tab.label,
              onTap: tab.onTap,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: tab.onTap,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: tab.selected ? GwentColors.gold : const Color(0x00000000), width: 2),
                    ),
                  ),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        tab.label,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: tab.selected ? GwentColors.gold : GwentColors.textSecondary,
                        ),
                      ),
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

class _Grid extends StatelessWidget {
  const _Grid({required this.loaded, required this.cards});

  final LoadedCardBook loaded;
  final List<BookCard> cards;

  static const double _cardWidth = 103;
  static const double _cardHeight = 148;
  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    final mapper = CardContentMapper(pack: loaded.data.pack, l10n: context.l10n);
    final rules = loaded.data.pack.rules;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _cardWidth * 3 + _gap * 2 + 32),
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: _gap,
            mainAxisSpacing: 14,
            childAspectRatio: _cardWidth / _cardHeight,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            final face = card.isOpen ? mapper.byId(card.cardId)?.face : null;
            return FittedBox(
              child: SizedBox(
                width: _cardWidth,
                height: _cardHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (face != null)
                      GwentCard(face: face, size: CardSize.grid)
                    else
                      _Silhouette(kind: rewardKindOf(rules, card.cardId)),
                    if (card.total > 1)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: _CopiesPill(owned: card.owned, total: card.total),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Закрытая карта: рубашка с «?» и видом карты.
class _Silhouette extends StatelessWidget {
  const _Silhouette({required this.kind});

  final RewardKind kind;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.rewardKindLabel(kind);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: 0.55,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const GwentCard(
              face: CardBackFace(faction: GwentFaction.neutral),
              size: CardSize.grid,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                const Text(
                  '?',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 36,
                    height: 1,
                    color: GwentColors.gold,
                  ),
                ),
                CampaignLabel(label.toUpperCase()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «1/2»: открыто копий из скольких есть.
class _CopiesPill extends StatelessWidget {
  const _CopiesPill({required this.owned, required this.total});

  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final full = owned >= total;
    return Semantics(
      label: context.l10n.campaignBookCopies(owned, total),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: full ? GwentColors.gold : GwentColors.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: GwentColors.gold),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            '$owned/$total',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1,
              color: full ? GwentColors.onGold : GwentColors.gold,
            ),
          ),
        ),
      ),
    );
  }
}
