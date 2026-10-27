import 'package:flutter/material.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/leader_name.dart';
import 'package:gwent/src/core/presentation/components/faction_medallion.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/status_tag.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/load_campaign_overview.dart';
import 'package:gwent/src/features/campaign/domain/campaign_path.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_texts.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_widgets.dart';
import 'package:gwent_content/gwent_content.dart';

/// Что игрок выбрал в листе узла.
enum NodeSheetChoice {
  /// «В бой» или «Сыграть ещё раз».
  play,

  /// Сменить колоду кампании.
  changeDeck,
}

/// Открывает лист узла поверх тропы (макет 17, экран 2): противник, награда, условие, колода и «В бой».
Future<NodeSheetChoice?> showCampaignNodeSheet(
  BuildContext context, {
  required CampaignOverview overview,
  required NodeView view,
}) => showModalBottomSheet<NodeSheetChoice>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: GwentColors.scrim,
  builder: (context) => CampaignNodeSheet(overview: overview, view: view),
);

/// Лист узла кампании.
class CampaignNodeSheet extends StatelessWidget {
  /// Создаёт лист узла [view].
  const CampaignNodeSheet({super.key, required this.overview, required this.view});

  /// Обзор кампании: тексты, колода игрока.
  final CampaignOverview overview;

  /// Узел.
  final NodeView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final node = view.node;
    final data = overview.data;
    final rules = data.pack.rules;
    final chapter = data.catalog.chapterOf(node.id)!;
    final index = chapter.nodes.indexWhere((candidate) => candidate.id == node.id) + 1;
    final opponent = node.opponent;
    final leader = opponent.leaderId == null ? null : rules.leaderCardsById[opponent.leaderId];
    final locked = view.status == NodeStatus.locked;
    final boss = node.kind == NodeKind.boss;
    final kicker = switch (node.kind) {
      NodeKind.order => l10n.campaignKickerOrder(chapter.number),
      NodeKind.boss => l10n.campaignKickerBoss(chapter.number),
      _ => l10n.campaignKickerNode(chapter.number, index),
    };
    final afterNode = node.afterId == null ? null : data.catalog.nodesById[node.afterId];
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1812), Color(0xFF14110E)],
        ),
        boxShadow: [BoxShadow(color: GwentColors.brass, offset: Offset(0, -1))],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                Center(
                  child: SizedBox(
                    width: 44,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: GwentColors.line, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                if (boss)
                  DecoratedBox(
                    decoration: BoxDecoration(color: GwentColors.lifeGemDeep, borderRadius: BorderRadius.circular(3)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        kicker.toUpperCase(),
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 14 * 0.1,
                          color: GwentColors.errorText,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    spacing: 10,
                    children: [
                      Expanded(child: CampaignLabel(kicker.toUpperCase(), color: GwentColors.gold)),
                      _StateChip(view: view),
                    ],
                  ),
                Row(
                  spacing: 12,
                  children: [
                    if (!node.isScripted)
                      FactionMedallion(faction: factionLook(rules, opponent.fractionId), size: 52, crestSize: 28),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          Text(
                            data.text(opponent.nameKey),
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: GwentText.cormorant,
                              fontWeight: FontWeight.w700,
                              fontSize: 26,
                              height: 1.05,
                              color: GwentColors.textPrimary,
                            ),
                          ),
                          if (!node.isScripted) DifficultyDiamonds(node.difficulty),
                        ],
                      ),
                    ),
                  ],
                ),
                if (node.isScripted)
                  Text(
                    l10n.campaignFirstMatchNote,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontSize: 16,
                      color: GwentColors.textTertiary,
                    ),
                  )
                else ...[
                  if (leader != null) _InfoLine(label: l10n.campaignLeaderLabel, value: _leaderName(data, leader)),
                  _InfoLine(label: l10n.campaignDeckThemeLabel, value: data.text(node.themeKey)),
                ],
                if (node.kind == NodeKind.order && !locked)
                  Text(
                    l10n.campaignOrderNote,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      color: GwentColors.textSecondary,
                    ),
                  ),
                _Rewards(overview: overview, view: view),
                if (!node.isScripted && !view.isComingSoon) _DeckRow(overview: overview, locked: locked),
                _Action(view: view, afterName: afterNode == null ? null : data.text(afterNode.opponent.nameKey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _leaderName(CampaignData data, LeaderCard leader) => splitLeaderName(data.text(leader.nameKey)).$1;
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.view});

  final NodeView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (text, background, color) = switch (view) {
      NodeView(isComingSoon: true) => (l10n.campaignChipSoon, GwentColors.surfaceWarm, GwentColors.textSecondary),
      NodeView(status: NodeStatus.locked) => (
        l10n.campaignChipLocked,
        GwentColors.surfaceWarm,
        GwentColors.textSecondary,
      ),
      NodeView(status: NodeStatus.open) => (l10n.campaignChipOpen, GwentColors.gold, GwentColors.onGold),
      NodeView() => (l10n.campaignChipPassed, GwentColors.goldSurface, GwentColors.gold),
    };
    return StatusTag(text.toUpperCase(), background: background, color: color);
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 3,
    children: [
      CampaignLabel(label.toUpperCase()),
      Text(
        value,
        style: const TextStyle(
          fontFamily: GwentText.alegreya,
          fontSize: 17,
          height: 1.2,
          color: GwentColors.textPrimary,
        ),
      ),
    ],
  );
}

/// Награда силуэтами и условие дополнительной награды. Пройденный узел показывает награду первой победы названиями.
class _Rewards extends StatelessWidget {
  const _Rewards({required this.overview, required this.view});

  final CampaignOverview overview;
  final NodeView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final node = view.node;
    final rules = overview.data.pack.rules;
    final muted = view.status == NodeStatus.locked;
    final passed = view.status == NodeStatus.passed;
    final bonus = node.bonus;
    Widget silhouettes(List<CardGrant> grants) => Wrap(
      spacing: 14,
      runSpacing: 10,
      children: [
        for (final grant in grants)
          RewardSilhouette(kind: rewardKindOf(rules, grant.cardId), copies: grant.copies, muted: muted),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        CampaignLabel(l10n.campaignRewardLabel.toUpperCase()),
        if (passed)
          Text(
            l10n.campaignRewardClaimed,
            style: const TextStyle(fontFamily: GwentText.alegreya, fontSize: 16, color: GwentColors.textSecondary),
          )
        else
          silhouettes(node.reward),
        if (bonus != null)
          ParchmentPlate(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  '${view.bonusClaimed ? '★' : '☆'} ${l10n.campaignBonusLabel.toUpperCase()}',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 13 * 0.08,
                    color: GwentColors.onParchmentSecondary,
                  ),
                ),
                Text(
                  l10n.conditionLabel(bonus.condition),
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    color: GwentColors.onParchment,
                  ),
                ),
                if (view.bonusClaimed)
                  Text(
                    l10n.campaignBonusClaimed,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontSize: 15,
                      color: GwentColors.onParchmentSecondary,
                    ),
                  )
                else
                  silhouettes(bonus.reward),
              ],
            ),
          ),
      ],
    );
  }
}

class _DeckRow extends StatelessWidget {
  const _DeckRow({required this.overview, required this.locked});

  final CampaignOverview overview;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final deck = overview.deck;
    final row = DecoratedBox(
      decoration: BoxDecoration(
        color: GwentColors.rowSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GwentColors.panelLine),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          spacing: 10,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  CampaignLabel(l10n.campaignYourDeck.toUpperCase()),
                  Text(
                    deck?.name ?? l10n.campaignDeckNone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: GwentText.cormorant,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: deck == null ? GwentColors.errorText : GwentColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (deck != null)
              StatusTag(
                l10n.campaignDeckReady.toUpperCase(),
                background: GwentColors.goldSurface,
                color: GwentColors.gold,
              ),
            const Icon(Icons.chevron_right, color: GwentColors.textSecondary),
          ],
        ),
      ),
    );
    if (locked) return Opacity(opacity: 0.6, child: row);
    return Semantics(
      button: true,
      label: '${l10n.campaignYourDeck}: ${deck?.name ?? l10n.campaignDeckNone}',
      excludeSemantics: true,
      onTap: () => Navigator.of(context).pop(NodeSheetChoice.changeDeck),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(NodeSheetChoice.changeDeck),
        child: row,
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.view, required this.afterName});

  final NodeView view;
  final String? afterName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (view) {
      NodeView(node: CampaignNode(isScripted: true)) => l10n.campaignStartFirstMatch,
      NodeView(status: NodeStatus.passed) => l10n.campaignPlayAgain,
      _ => l10n.campaignToBattle,
    };
    final note = switch (view) {
      NodeView(isComingSoon: true) => l10n.campaignChapterSoonNote,
      NodeView(status: NodeStatus.locked) when afterName != null => l10n.campaignWinFirst(afterName!),
      NodeView(status: NodeStatus.passed) => l10n.campaignRewardClaimed,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        GwentButton(
          label: label,
          onPressed: view.isPlayable ? () => Navigator.of(context).pop(NodeSheetChoice.play) : null,
        ),
        if (note != null && view.status != NodeStatus.passed)
          Text(
            note,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: GwentText.alegreya, fontSize: 15, color: GwentColors.textSecondary),
          ),
      ],
    );
  }
}
