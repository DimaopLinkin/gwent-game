import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_content_mapper.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/card/leader_name.dart';
import 'package:gwent/src/core/presentation/components/chevron_button.dart';
import 'package:gwent/src/core/presentation/components/diamond_marker.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_labels.dart';
import 'package:gwent/src/core/presentation/components/status_tag.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_state.dart';
import 'package:gwent/src/features/deck_builder/presentation/editor/editor_sheets.dart';

/// Список колод игрока (макет 8, «Список колод»): колоды с фракцией, лидером и счётчиками, удаление с
/// подтверждением и кнопка «Новая колода».
///
/// Колода, нарушающая правила, подсвечена красным. Без набора карт колоды видны без фракций и лидеров.
class DeckListScreen extends StatelessWidget {
  /// Создаёт экран; [onOpen] открывает колоду в конструкторе, [onNew] начинает новую, [onBack] выходит в меню.
  const DeckListScreen({super.key, required this.onOpen, required this.onNew, required this.onBack});

  /// Игрок открыл колоду с идентификатором `deckId`.
  final ValueChanged<String> onOpen;

  /// Игрок хочет собрать новую колоду.
  final VoidCallback onNew;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: 12,
                children: [
                  ChevronButton(label: l10n.setupBack, onPressed: onBack),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 5,
                      children: [
                        Eyebrow(l10n.deckListEyebrow),
                        ScreenTitle(l10n.deckListTitle, size: 34, color: GwentColors.goldHighlight),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BlocBuilder<DeckListCubit, DeckListState>(
                  builder: (context, state) => switch (state) {
                    DeckListLoading() => const GameLoader(),
                    DeckListFailed() => _Message(l10n.deckListLoadFailed),
                    DeckListLoaded(:final decks, :final rules) => _Decks(
                      decks: decks,
                      rules: rules,
                      onOpen: onOpen,
                      onNew: onNew,
                      onDelete: (deck) async {
                        final cubit = context.read<DeckListCubit>();
                        if (await showDeleteDeckSheet(context, deck.name)) await cubit.delete(deck.id);
                      },
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontFamily: GwentText.alegreya, fontSize: 17, color: GwentColors.textSecondary),
    ),
  );
}

class _Decks extends StatelessWidget {
  const _Decks({
    required this.decks,
    required this.rules,
    required this.onOpen,
    required this.onNew,
    required this.onDelete,
  });

  final List<Deck> decks;
  final DeckRules? rules;
  final ValueChanged<String> onOpen;
  final VoidCallback onNew;
  final ValueChanged<Deck> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rules = this.rules;
    final mapper = rules == null ? null : CardContentMapper(pack: rules.pack, l10n: l10n);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (decks.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 14), child: _Message(l10n.deckListEmpty)),
        for (final deck in decks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DeckRow(
              deck: deck,
              rules: rules,
              mapper: mapper,
              onOpen: () => onOpen(deck.id),
              onDelete: () => onDelete(deck),
            ),
          ),
        _NewDeckButton(label: l10n.deckListNew, onPressed: onNew),
      ],
    );
  }
}

class _DeckRow extends StatelessWidget {
  const _DeckRow({
    required this.deck,
    required this.rules,
    required this.mapper,
    required this.onOpen,
    required this.onDelete,
  });

  final Deck deck;
  final DeckRules? rules;
  final CardContentMapper? mapper;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rules = this.rules;
    final mapper = this.mapper;
    final faction = rules?.factionInfos.where((info) => info.id == deck.factionId).firstOrNull;
    final leader = rules?.pack.rules.leaderCardsById[deck.leaderId];
    final stats = rules?.statsOf(DeckDraft.of(deck));
    final invalid = rules != null && rules.check(deck).isNotEmpty;
    final minUnits = rules?.gameRules.minUnitCards ?? 0;
    final maxSpecials = rules?.gameRules.maxSpecialCards ?? 0;
    final look = faction == null ? null : GwentFaction.fromKey(faction.key);

    Widget stat(String text, {bool bad = false}) => Text(
      text,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: GwentText.alegreya,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        height: 1,
        color: bad ? GwentColors.errorText : GwentColors.textTertiary,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: GwentColors.rowSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: invalid ? GwentColors.debuff : GwentColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: l10n.deckListOpen(deck.name),
                onTap: onOpen,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpen,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      if (leader != null && mapper != null)
                        GwentCard(face: mapper.leader(leader).face, size: CardSize.row),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 5,
                          children: [
                            Text(
                              deck.name,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontFamily: GwentText.cormorant,
                                fontWeight: FontWeight.w700,
                                fontSize: 21,
                                height: 1.05,
                                color: GwentColors.textPrimary,
                              ),
                            ),
                            if (faction != null && look != null && leader != null)
                              Row(
                                spacing: 6,
                                children: [
                                  DiamondMarker(size: 8, color: look.accent),
                                  Expanded(
                                    child: Text(
                                      '${faction.name} · ${splitLeaderName(rules!.pack.text(leader.nameKey)).$1}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textScaler: TextScaler.noScaling,
                                      style: const TextStyle(
                                        fontFamily: GwentText.alegreya,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        height: 1.2,
                                        color: GwentColors.textTertiary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (stats == null)
                              stat(l10n.deckCardCount(deck.cardCount))
                            else
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  stat(l10n.deckListTotal(stats.total)),
                                  stat(
                                    l10n.deckListUnits(stats.units, minUnits),
                                    bad: stats.units < minUnits,
                                  ),
                                  stat(
                                    l10n.deckListSpecials(stats.specials, maxSpecials),
                                    bad: stats.specials > maxSpecials,
                                  ),
                                ],
                              ),
                            if (invalid)
                              StatusTag(
                                l10n.deckListInvalid,
                                background: GwentColors.errorSurface,
                                color: GwentColors.errorText,
                                ring: GwentColors.debuff,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: l10n.deckListDelete,
              onTap: onDelete,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDelete,
                child: const SizedBox.square(dimension: 44, child: CustomPaint(painter: _TrashPainter())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewDeckButton extends StatelessWidget {
  const _NewDeckButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onPressed,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: GwentColors.muted, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            const Text(
              '+',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: GwentText.cormorant,
                fontWeight: FontWeight.w700,
                fontSize: 30,
                color: GwentColors.goldHighlight,
              ),
            ),
            Text(
              label,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.cormorant,
                fontWeight: FontWeight.w700,
                fontSize: 21,
                letterSpacing: 1,
                color: GwentColors.goldHighlight,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Корзина из макета: крышка и корпус линиями 2 pt в квадрате 44×44.
class _TrashPainter extends CustomPainter {
  const _TrashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 44;
    final path = Path()
      ..moveTo(14 * scale, 16 * scale)
      ..lineTo(30 * scale, 16 * scale)
      ..moveTo(18 * scale, 16 * scale)
      ..lineTo(18 * scale, 14 * scale)
      ..lineTo(26 * scale, 14 * scale)
      ..lineTo(26 * scale, 16 * scale)
      ..moveTo(16 * scale, 16 * scale)
      ..lineTo(17 * scale, 30 * scale)
      ..lineTo(27 * scale, 30 * scale)
      ..lineTo(28 * scale, 16 * scale)
      ..moveTo(20 * scale, 20 * scale)
      ..lineTo(20 * scale, 27 * scale)
      ..moveTo(24 * scale, 20 * scale)
      ..lineTo(24 * scale, 27 * scale);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = GwentColors.textSecondary,
    );
  }

  @override
  bool shouldRepaint(_TrashPainter oldDelegate) => false;
}
