import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_content_mapper.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/card/leader_name.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_texts.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_widgets.dart';
import 'package:gwent_content/gwent_content.dart';

/// Экран награды после победы (макет 17, экран 4): карты лежат рубашкой вверх и переворачиваются по касанию,
/// условие, счёт открытых карт, новый лидер, открытая глава и колода фракции.
///
/// Награда большого набора (стартовый набор) показывается сразу и без переворотов: перелистывать три десятка карт
/// по одной незачем. Скорость и «Уменьшить движение» учитываются: без движения всё появляется сразу.
class CampaignRewardView extends StatefulWidget {
  /// Создаёт экран награды победы [won].
  const CampaignRewardView({
    super.key,
    required this.won,
    required this.data,
    required this.onNext,
    required this.onTrail,
    required this.onBuildDeck,
  });

  /// Наибольшее число карт, которое переворачивают по одной.
  static const int flipLimit = 5;

  /// Победа, чью награду показывают.
  final CampaignWon won;

  /// Каталог и тексты.
  final CampaignData data;

  /// «Дальше»: открыть лист узла с этим идентификатором (партия начинается на листе, а не сразу).
  final ValueChanged<String> onNext;

  /// «К тропе».
  final VoidCallback onTrail;

  /// «Собрать колоду» новой фракции.
  final VoidCallback onBuildDeck;

  @override
  State<CampaignRewardView> createState() => _CampaignRewardViewState();
}

class _CampaignRewardViewState extends State<CampaignRewardView> {
  final Set<String> _revealed = {};

  List<CardGrant> get _first => widget.won.firstWinReward;
  List<CardGrant> get _bonus => widget.won.bonusReward;
  bool get _bulk => _first.length + _bonus.length > CampaignRewardView.flipLimit;

  bool get _allRevealed =>
      _bulk ||
      [
        for (final (i, _) in _first.indexed) 'f$i',
        for (final (i, _) in _bonus.indexed) 'b$i',
      ].every(_revealed.contains);

  void _revealAll() => setState(() {
    _revealed
      ..addAll([for (final (i, _) in _first.indexed) 'f$i'])
      ..addAll([for (final (i, _) in _bonus.indexed) 'b$i']);
  });

  String? get _nextNodeId {
    final catalog = widget.data.catalog;
    for (final id in widget.won.unlockedNodeIds) {
      if (catalog.nodesById[id]?.kind != NodeKind.order) return id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final won = widget.won;
    final data = widget.data;
    final rules = data.pack.rules;
    final node = data.catalog.nodesById[won.nodeId]!;
    final mapper = CardContentMapper(pack: data.pack, l10n: l10n);
    final nextId = _nextNodeId;
    final newFaction = won.newFactionIds.isEmpty ? null : rules.fractionsById[won.newFactionIds.first];
    final newLeader = [
      ...won.firstWinReward,
      ...won.bonusReward,
    ].map((grant) => rules.leaderCardsById[grant.cardId]).whereType<LeaderCard>().firstOrNull;
    final cleared = won.chapterCleared;
    final nextChapter = cleared == null
        ? null
        : data.catalog.chapters.where((chapter) => chapter.number == cleared.number + 1).firstOrNull;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final condition = node.bonus?.condition;

    Widget cards(List<CardGrant> grants, String prefix) => Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final (i, grant) in grants.indexed)
          _bulk
              ? _MiniFace(face: mapper.byId(grant.cardId)?.face, copies: grant.copies)
              : _FlipCard(
                  face: mapper.byId(grant.cardId)?.face,
                  kind: rewardKindOf(rules, grant.cardId),
                  label: won.newCardIds.contains(grant.cardId)
                      ? l10n.campaignNewCard
                      : l10n.campaignExtraCopies(grant.copies),
                  copies: grant.copies,
                  revealed: _revealed.contains('$prefix$i'),
                  reduceMotion: reduce,
                  onTap: () => setState(() => _revealed.add('$prefix$i')),
                ),
      ],
    );

    return ScreenBackdrop(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Column(
                    spacing: 4,
                    children: [
                      Text(
                        l10n.campaignVictory.toUpperCase(),
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 34,
                          letterSpacing: 34 * 0.08,
                          color: GwentColors.goldHighlight,
                        ),
                      ),
                      Text(
                        data.text(node.opponent.nameKey),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          color: GwentColors.textPrimary,
                        ),
                      ),
                      CampaignLabel(
                        (cleared == null ? l10n.campaignNodePassed : l10n.campaignChapterClearedRibbon(cleared.number))
                            .toUpperCase(),
                        color: GwentColors.gold,
                      ),
                    ],
                  ),
                  if (_first.isNotEmpty) ...[
                    Center(
                      child: CampaignLabel(
                        (_bulk ? l10n.campaignStartingSetLabel : l10n.campaignRewardLabel).toUpperCase(),
                      ),
                    ),
                    cards(_first, 'f'),
                  ],
                  if (won.bonusMet && condition != null)
                    ParchmentPlate(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 10,
                        children: [
                          Text(
                            l10n.campaignConditionMet.toUpperCase(),
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
                            l10n.conditionLabel(condition),
                            style: const TextStyle(
                              fontFamily: GwentText.alegreya,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: GwentColors.onParchment,
                            ),
                          ),
                          if (_bonus.isEmpty)
                            Text(
                              l10n.campaignBonusClaimed,
                              style: const TextStyle(
                                fontFamily: GwentText.alegreya,
                                fontSize: 15,
                                color: GwentColors.onParchmentSecondary,
                              ),
                            )
                          else
                            Center(child: cards(_bonus, 'b')),
                        ],
                      ),
                    ),
                  if (!_allRevealed)
                    Center(
                      child: Text(
                        l10n.campaignTapToOpen,
                        style: const TextStyle(
                          fontFamily: GwentText.alegreya,
                          fontStyle: FontStyle.italic,
                          fontSize: 16,
                          color: GwentColors.textSecondary,
                        ),
                      ),
                    ),
                  if (_allRevealed) ...[
                    if (newLeader != null)
                      _Notice(
                        title: l10n.campaignNewLeader(splitLeaderName(data.text(newLeader.nameKey)).$1),
                        body: l10n.campaignNewLeaderBody,
                      ),
                    if (nextChapter != null && nextChapter.released)
                      _Notice(
                        title: l10n.campaignChapterOpened(nextChapter.number, data.text(nextChapter.nameKey)),
                        body: l10n.campaignChapterOpenedBody,
                      ),
                    if (newFaction != null)
                      _Notice(
                        title: l10n.campaignFactionReady(data.text(newFaction.nameKey)),
                        body: l10n.campaignFactionReadyBody(rules.gameRules.minSquadCards),
                      ),
                    if (won.openedAfter > won.openedBefore)
                      _Counter(
                        before: won.openedBefore,
                        after: won.openedAfter,
                        total: won.totalCards,
                        reduceMotion: reduce,
                      ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              spacing: 10,
              children: [
                if (!_allRevealed)
                  SizedBox(
                    width: double.infinity,
                    child: GwentButton(
                      label: l10n.campaignSkip,
                      style: GwentButtonStyle.secondary,
                      onPressed: _revealAll,
                    ),
                  )
                else ...[
                  if (newFaction != null)
                    SizedBox(
                      width: double.infinity,
                      child: GwentButton(
                        label: l10n.campaignBuildFactionDeck(data.text(newFaction.nameKey)),
                        fontSize: 20,
                        maxLines: 2,
                        onPressed: widget.onBuildDeck,
                      ),
                    ),
                  if (nextId != null)
                    SizedBox(
                      width: double.infinity,
                      child: GwentButton(
                        label: l10n.campaignNext(data.text(data.catalog.nodesById[nextId]!.opponent.nameKey)),
                        style: newFaction == null ? GwentButtonStyle.primary : GwentButtonStyle.secondary,
                        fontSize: 20,
                        maxLines: 2,
                        onPressed: () => widget.onNext(nextId),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: GwentButton(
                      label: l10n.campaignToTrail,
                      style: GwentButtonStyle.secondary,
                      onPressed: widget.onTrail,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Карта награды: рубашка с «?», по касанию переворачивается (0,5 с); ярлык «Новая карта» или «+1 копия» появляется
/// чуть позже. Без движения лицо появляется сразу.
class _FlipCard extends StatefulWidget {
  const _FlipCard({
    required this.face,
    required this.kind,
    required this.label,
    required this.copies,
    required this.revealed,
    required this.reduceMotion,
    required this.onTap,
  });

  final CardFace? face;
  final RewardKind kind;
  final String label;
  final int copies;
  final bool revealed;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: widget.revealed ? 1 : 0,
  );

  @override
  void didUpdateWidget(_FlipCard old) {
    super.didUpdateWidget(old);
    if (widget.revealed && !old.revealed) {
      if (widget.reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final face = widget.face;
    return Semantics(
      button: !widget.revealed,
      label: widget.revealed ? widget.label : context.l10n.campaignTapToOpen,
      excludeSemantics: true,
      onTap: widget.revealed ? null : widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.revealed ? null : widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // scaleX 1 → 0 → 1, лицо подменяется на середине.
                final t = _controller.value;
                final scale = (1 - 2 * t).abs();
                final showFace = t >= 0.5 && face != null;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(math.max(scale, 0.001), 1, 1),
                  child: SizedBox(
                    width: 150,
                    height: 216,
                    child: FittedBox(
                      child: showFace
                          ? GwentCard(face: face, size: CardSize.full)
                          : const GwentCard(
                              face: CardBackFace(faction: GwentFaction.neutral),
                              size: CardSize.full,
                            ),
                    ),
                  ),
                );
              },
            ),
            AnimatedOpacity(
              opacity: widget.revealed ? 1 : 0,
              duration: widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
              child: CampaignLabel(widget.label.toUpperCase(), color: GwentColors.gold),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniFace extends StatelessWidget {
  const _MiniFace({required this.face, required this.copies});

  final CardFace? face;
  final int copies;

  @override
  Widget build(BuildContext context) {
    final face = this.face;
    if (face == null) return const SizedBox.shrink();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GwentCard(face: face, size: CardSize.row),
        if (copies > 1)
          Positioned(
            right: -4,
            bottom: -4,
            child: DecoratedBox(
              decoration: BoxDecoration(color: GwentColors.gold, borderRadius: BorderRadius.circular(999)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                child: Text(
                  '×$copies',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: GwentColors.onGold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: GwentColors.goldSurface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: GwentColors.brass),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: GwentColors.goldHighlight,
            ),
          ),
          Text(
            body,
            style: const TextStyle(fontFamily: GwentText.alegreya, fontSize: 15, color: GwentColors.textTertiary),
          ),
        ],
      ),
    ),
  );
}

/// Счётчик «Открыто карт: N → M из T»: число растёт за 0,6 с, итог остаётся золотым.
class _Counter extends StatelessWidget {
  const _Counter({required this.before, required this.after, required this.total, required this.reduceMotion});

  final int before;
  final int after;
  final int total;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => Column(
    spacing: 4,
    children: [
      CampaignLabel(context.l10n.campaignOpenedLabel.toUpperCase()),
      TweenAnimationBuilder<int>(
        tween: IntTween(begin: before, end: after),
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        builder: (context, value, _) => Text(
          context.l10n.campaignOpenedCounter(before, value, total),
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: GwentText.cormorant,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: value == after ? GwentColors.goldHighlight : GwentColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}
