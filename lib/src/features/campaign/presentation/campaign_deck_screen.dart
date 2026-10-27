import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/leader_name.dart';
import 'package:gwent/src/core/presentation/components/faction_medallion.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/components/status_tag.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/domain/campaign_deck.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_deck_cubit.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_deck_state.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_texts.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_widgets.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_issue_text.dart';

/// «Колода для боя» (макет 17, экран 3): колоды игрока с оценкой для кампании, годные первыми, негодные серые с
/// причиной. Без годной колоды главное действие — «Собрать колоду» в конструкторе кампании.
///
/// Ждёт `CampaignDeckCubit` выше по дереву.
class CampaignDeckScreen extends StatelessWidget {
  /// Создаёт экран. [onBattle] вызывается после выбора, если игрок идёт в бой на узел; без узла выбор просто
  /// запоминается и экран закрывается через [onChosen].
  const CampaignDeckScreen({
    super.key,
    required this.onBack,
    required this.onBattle,
    required this.onChosen,
    required this.onBuild,
    required this.onEdit,
  });

  /// Назад, ничего не выбрав.
  final VoidCallback onBack;

  /// Выбор запомнен, идти в бой на узел с этим идентификатором.
  final ValueChanged<String> onBattle;

  /// Выбор запомнен, узла нет.
  final VoidCallback onChosen;

  /// Собрать колоду в конструкторе кампании; завершается, когда игрок вернулся (список колод читается заново).
  final Future<void> Function() onBuild;

  /// Изменить колоду с этим идентификатором в конструкторе кампании; завершается, когда игрок вернулся.
  final Future<void> Function(String deckId) onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: Column(
        children: [
          ScreenHeader(title: l10n.campaignDeckScreenTitle, onBack: onBack),
          Expanded(
            child: BlocBuilder<CampaignDeckCubit, CampaignDeckState>(
              builder: (context, state) => switch (state) {
                CampaignDeckLoading() => const GameLoader(),
                CampaignDeckFailed() => Center(child: Text(l10n.deckListLoadFailed)),
                final CampaignDeckLoaded loaded => _Body(
                  state: loaded,
                  onBattle: onBattle,
                  onChosen: onChosen,
                  onBuild: onBuild,
                  onEdit: onEdit,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.onBattle,
    required this.onChosen,
    required this.onBuild,
    required this.onEdit,
  });

  final CampaignDeckLoaded state;
  final ValueChanged<String> onBattle;
  final VoidCallback onChosen;
  final Future<void> Function() onBuild;
  final Future<void> Function(String deckId) onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CampaignDeckCubit>();
    final node = state.node;
    final data = state.data;
    final minUnits = data.pack.rules.gameRules.minSquadCards;
    Future<void> confirm() async {
      final ok = await cubit.confirm();
      if (!ok || !context.mounted) return;
      if (node == null) {
        onChosen();
      } else {
        onBattle(node.id);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          if (node != null)
            Row(
              spacing: 8,
              children: [
                CampaignLabel(l10n.campaignBattleLabel.toUpperCase(), color: GwentColors.gold),
                Expanded(
                  child: Text(
                    '${data.text(node.opponent.nameKey)} · ${l10n.difficultyLabel(node.difficulty)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontSize: 16,
                      color: GwentColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          Expanded(
            child: state.decks.isEmpty
                ? _Empty(minUnits: minUnits)
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // Негодные колоды видны и без годных: их можно довести до годных кнопкой «Изменить».
                      if (!state.hasReady) _NoReadyNote(minUnits: minUnits),
                      for (final entry in state.decks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DeckRow(
                            entry: entry,
                            data: data,
                            selected: entry.deck.id == state.selectedId,
                            onTap: entry.isReady ? () => cubit.select(entry.deck.id) : null,
                            onEdit: () async {
                              await onEdit(entry.deck.id);
                              if (context.mounted) unawaited(cubit.reload());
                            },
                          ),
                        ),
                    ],
                  ),
          ),
          if (state.hasReady)
            GwentButton(
              label: node == null ? l10n.campaignChooseDeck : l10n.campaignToBattle,
              onPressed: state.selectedId == null ? null : confirm,
            ),
          GwentButton(
            label: l10n.campaignBuildDeck,
            style: state.hasReady ? GwentButtonStyle.secondary : GwentButtonStyle.primary,
            fontSize: 21,
            onPressed: () async {
              await onBuild();
              if (context.mounted) unawaited(cubit.reload());
            },
          ),
        ],
      ),
    );
  }
}

class _NoReadyNote extends StatelessWidget {
  const _NoReadyNote({required this.minUnits});

  final int minUnits;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            l10n.campaignNoDeckTitle,
            style: const TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: GwentColors.textPrimary,
            ),
          ),
          Text(
            l10n.campaignNoDeckBody(minUnits),
            style: const TextStyle(fontFamily: GwentText.alegreya, fontSize: 16, color: GwentColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.minUnits});

  final int minUnits;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          const GwentIconView(GwentIcon.iconDeck, size: 56, color: GwentColors.brass),
          Text(
            l10n.campaignNoDeckTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 24,
              color: GwentColors.textPrimary,
            ),
          ),
          Text(
            l10n.campaignNoDeckBody(minUnits),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: GwentText.alegreya, fontSize: 17, color: GwentColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DeckRow extends StatelessWidget {
  const _DeckRow({
    required this.entry,
    required this.data,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });

  final CampaignDeck entry;
  final CampaignData data;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final deck = entry.deck;
    final rules = data.pack.rules;
    final ready = entry.isReady;
    final leader = rules.leaderCardsById[deck.leaderId];
    final units = deck.cards.entries.fold(
      0,
      (sum, card) => rules.squadCardsById.containsKey(card.key) ? sum + card.value : sum,
    );
    final reason = ready ? null : DeckIssueText(pack: data.pack, l10n: l10n).firstOf(entry.issues);
    final details = [
      if (leader != null) splitLeaderName(data.text(leader.nameKey)).$1,
      l10n.campaignDeckUnits(units),
    ].join(' · ');
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: [deck.name, details, reason ?? l10n.campaignDeckReady].join('. '),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: ready ? 1 : 0.6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? GwentColors.rowSelected : GwentColors.rowSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? GwentColors.gold : (ready ? GwentColors.panelLine : GwentColors.dangerPanelRing),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                spacing: 12,
                children: [
                  FactionMedallion(faction: factionLook(rules, deck.factionId), size: 48, crestSize: 26),
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
                        Text(
                          details,
                          style: const TextStyle(
                            fontFamily: GwentText.alegreya,
                            fontSize: 14,
                            color: GwentColors.textTertiary,
                          ),
                        ),
                        if (reason != null)
                          Text(
                            reason,
                            style: const TextStyle(
                              fontFamily: GwentText.alegreya,
                              fontSize: 13,
                              color: GwentColors.errorText,
                            ),
                          )
                        else
                          StatusTag(
                            l10n.campaignDeckReady.toUpperCase(),
                            background: GwentColors.goldSurface,
                            color: GwentColors.gold,
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    const DecoratedBox(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: GwentColors.gold),
                      child: SizedBox.square(dimension: 12),
                    ),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onEdit,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        child: Center(
                          child: Text(
                            l10n.campaignEditDeck,
                            style: const TextStyle(
                              fontFamily: GwentText.alegreya,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: GwentColors.gold,
                            ),
                          ),
                        ),
                      ),
                    ),
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
