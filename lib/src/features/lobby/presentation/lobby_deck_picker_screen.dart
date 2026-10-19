import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/leader_name.dart';
import 'package:gwent/src/core/presentation/components/faction_medallion.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_issue_text.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_state.dart';

/// Выбор сохранённой колоды для лобби (макет 9, экран 4b): список колод, одна выбрана, кнопки «Выбрать» и «Собрать
/// новую». Колода, нарушающая правила, приглушена с причиной, но выбрать её можно: «Готов» в лобби ей закрыта.
///
/// Ждёт `DeckListCubit` выше по дереву.
class LobbyDeckPickerScreen extends StatefulWidget {
  /// Создаёт экран; [initialDeckId] — колода, выбранная сейчас.
  const LobbyDeckPickerScreen({
    super.key,
    required this.onSelect,
    required this.onBuildNew,
    required this.onBack,
    this.initialDeckId,
  });

  /// Колода, выбранная в лобби сейчас; `null`, если колоды ещё нет.
  final String? initialDeckId;

  /// Игрок выбрал колоду с идентификатором из параметра.
  final ValueChanged<String> onSelect;

  /// Игрок хочет собрать новую колоду.
  final VoidCallback onBuildNew;

  /// Игрок вернулся назад, ничего не выбрав.
  final VoidCallback onBack;

  @override
  State<LobbyDeckPickerScreen> createState() => _LobbyDeckPickerScreenState();
}

class _LobbyDeckPickerScreenState extends State<LobbyDeckPickerScreen> {
  late String? _selected = widget.initialDeckId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: Column(
        children: [
          ScreenHeader(
            title: l10n.netPickerTitle,
            subtitle: l10n.netPickerSubtitle,
            titleSize: 32,
            onBack: widget.onBack,
          ),
          Expanded(
            child: BlocBuilder<DeckListCubit, DeckListState>(
              builder: (context, state) => switch (state) {
                DeckListLoading() => const GameLoader(),
                DeckListFailed() => Center(child: Text(l10n.deckListLoadFailed)),
                DeckListLoaded(:final decks, :final rules) => _body(context, decks, rules),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, List<Deck> decks, DeckRules? rules) {
    final l10n = context.l10n;
    final selected = decks.any((deck) => deck.id == _selected) ? _selected : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final deck in decks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DeckRow(
                      deck: deck,
                      rules: rules,
                      selected: deck.id == selected,
                      onTap: () => setState(() => _selected = deck.id),
                    ),
                  ),
              ],
            ),
          ),
          GwentButton(
            label: l10n.netPickerNew,
            style: GwentButtonStyle.secondary,
            fontSize: 21,
            onPressed: widget.onBuildNew,
          ),
          GwentButton(
            label: l10n.netDeckPick,
            fontSize: 21,
            onPressed: selected == null ? null : () => widget.onSelect(selected),
          ),
        ],
      ),
    );
  }
}

class _DeckRow extends StatelessWidget {
  const _DeckRow({required this.deck, required this.rules, required this.selected, required this.onTap});

  final Deck deck;
  final DeckRules? rules;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rules = this.rules;
    final faction = rules?.factionInfos.where((info) => info.id == deck.factionId).firstOrNull;
    final leader = faction?.leader(deck.leaderId);
    final look = faction == null ? GwentFaction.neutral : GwentFaction.fromKey(faction.key);
    final issues = rules?.check(deck) ?? const [];
    final invalid = issues.isNotEmpty;
    final stats = rules?.statsOf(DeckDraft.of(deck));
    final note = invalid
        ? DeckIssueText(pack: rules!.pack, l10n: l10n).firstOf(issues)
        : stats == null
        ? l10n.deckCardCount(deck.cardCount)
        : '${l10n.deckListUnits(stats.units, rules!.gameRules.minUnitCards)} · ${l10n.deckListSpecials(stats.specials, rules.gameRules.maxSpecialCards)}';
    final description = faction == null || leader == null
        ? null
        : l10n.netFactionLeader(faction.name, splitLeaderName(leader.name).$1);
    return Semantics(
      button: true,
      selected: selected,
      label: [deck.name, ?description, ?note].join('. '),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: invalid ? 0.7 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? GwentColors.rowSelected : GwentColors.rowSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? GwentColors.gold : (invalid ? GwentColors.dangerPanelRing : GwentColors.panelLine),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                spacing: 12,
                children: [
                  FactionMedallion(faction: look, size: 48, crestSize: 26),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 3,
                      children: [
                        Text(
                          deck.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: GwentText.cormorant,
                            fontWeight: FontWeight.w700,
                            fontSize: 21,
                            height: 1.1,
                            color: GwentColors.textPrimary,
                          ),
                        ),
                        if (description != null)
                          Text(
                            description,
                            style: const TextStyle(
                              fontFamily: GwentText.alegreya,
                              fontSize: 14,
                              color: GwentColors.textTertiary,
                            ),
                          ),
                        if (note != null)
                          Text(
                            note,
                            style: TextStyle(
                              fontFamily: GwentText.alegreya,
                              fontSize: 13,
                              color: invalid ? GwentColors.errorText : GwentColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    const DecoratedBox(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: GwentColors.gold),
                      child: SizedBox.square(dimension: 12),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
