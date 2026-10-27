import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/load_campaign_overview.dart';
import 'package:gwent/src/features/campaign/domain/campaign_path.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_cubit.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_node_sheet.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_reward_view.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_state.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_trail.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_widgets.dart';

/// Тропа ведьмака (макет 17, экран 1): шапка, колода и «Книга», главы с узлами и «Продолжить».
///
/// Ждёт `CampaignCubit` выше по дереву. Переходы приходят снаружи: экран не знает ни о маршрутах, ни о партии.
class CampaignScreen extends StatefulWidget {
  /// Создаёт экран.
  const CampaignScreen({
    super.key,
    required this.onBack,
    required this.onPlay,
    required this.onFirstMatch,
    required this.onPickDeck,
    required this.onBuildDeck,
    this.onBook,
  });

  /// Назад в меню.
  final VoidCallback onBack;

  /// Идти в бой на узле с этим идентификатором (колода выбрана).
  final ValueChanged<String> onPlay;

  /// Пройти «Первую партию» (узел 0).
  final VoidCallback onFirstMatch;

  /// Выбрать колоду кампании; с узлом после выбора идут в бой на него. Завершается, когда игрок вернулся.
  final Future<void> Function(String? nodeId) onPickDeck;

  /// Собрать колоду в конструкторе кампании. Завершается, когда игрок вернулся: тропа читается заново.
  final Future<void> Function() onBuildDeck;

  /// Открыть «Книгу карт»; `null` — пилюля «Книга» только показывает счёт.
  final VoidCallback? onBook;

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  /// Главы, раскрытые игроком вручную; текущая раскрыта всегда.
  final Set<int> _toggled = {};

  Future<void> _openNode(CampaignOverview overview, NodeView view) async {
    final choice = await showCampaignNodeSheet(context, overview: overview, view: view);
    if (!mounted || choice == null) return;
    switch (choice) {
      case NodeSheetChoice.changeDeck:
        await widget.onPickDeck(null);
        if (mounted) unawaited(context.read<CampaignCubit>().refresh());
      case NodeSheetChoice.play when view.node.isScripted:
        widget.onFirstMatch();
      case NodeSheetChoice.play when overview.deck == null:
        await widget.onPickDeck(view.node.id);
        if (mounted) unawaited(context.read<CampaignCubit>().refresh());
      case NodeSheetChoice.play:
        widget.onPlay(view.node.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: BlocBuilder<CampaignCubit, CampaignState>(
        builder: (context, state) => switch (state) {
          CampaignLoading() => Column(
            children: [
              ScreenHeader(title: l10n.campaignTitle, onBack: widget.onBack),
              const Expanded(child: GameLoader()),
            ],
          ),
          CampaignUnavailable() => Column(
            children: [
              ScreenHeader(title: l10n.campaignTitle, onBack: widget.onBack),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.campaignUnavailable,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: GwentText.alegreya,
                        fontSize: 18,
                        color: GwentColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          CampaignReady(:final overview, :final pendingReward) => Stack(
            fit: StackFit.expand,
            children: [
              _Trail(
                overview: overview,
                toggled: _toggled,
                onToggle: (number) =>
                    setState(() => _toggled.contains(number) ? _toggled.remove(number) : _toggled.add(number)),
                onBack: widget.onBack,
                onBook: widget.onBook,
                onPickDeck: () async {
                  await widget.onPickDeck(null);
                  if (context.mounted) unawaited(context.read<CampaignCubit>().refresh());
                },
                onOpen: (view) => _openNode(overview, view),
              ),
              if (pendingReward != null)
                CampaignRewardView(
                  won: pendingReward,
                  data: overview.data,
                  onNext: (nodeId) {
                    context.read<CampaignCubit>().rewardSeen();
                    widget.onPlay(nodeId);
                  },
                  onTrail: context.read<CampaignCubit>().rewardSeen,
                  onBuildDeck: () async {
                    final cubit = context.read<CampaignCubit>()..rewardSeen();
                    await widget.onBuildDeck();
                    if (mounted) unawaited(cubit.refresh());
                  },
                ),
            ],
          ),
        },
      ),
    );
  }
}

class _Trail extends StatelessWidget {
  const _Trail({
    required this.overview,
    required this.toggled,
    required this.onToggle,
    required this.onBack,
    required this.onBook,
    required this.onPickDeck,
    required this.onOpen,
  });

  final CampaignOverview overview;
  final Set<int> toggled;
  final ValueChanged<int> onToggle;
  final VoidCallback onBack;
  final VoidCallback? onBook;
  final VoidCallback onPickDeck;
  final ValueChanged<NodeView> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final path = overview.path;
    final current = path.current;
    final currentChapter = path.currentChapter;
    return Column(
      children: [
        ScreenHeader(title: l10n.campaignTitle, onBack: onBack),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                flex: 3,
                child: _Pill(
                  label: l10n.campaignDeckPill(overview.deck?.name ?? l10n.campaignDeckNotChosen),
                  onTap: onPickDeck,
                ),
              ),
              Expanded(
                flex: 2,
                child: _Pill(label: l10n.campaignBookPill(overview.opened, overview.total), onTap: onBook),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  for (final chapter in path.chapters)
                    if (chapter.isUnlocked &&
                        (chapter == currentChapter || toggled.contains(chapter.chapter.number))) ...[
                      // Строка текущей главы залипает; раскрытые вручную главы показывают её обычной строкой.
                      if (chapter == currentChapter)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _ChapterStrip(chapter: chapter, data: overview.data, l10n: l10n),
                        )
                      else
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 36,
                            child: _ChapterStripView(chapter: chapter, data: overview.data, l10n: l10n),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: _ChapterCard(
                            chapter: chapter,
                            name: overview.data.text(chapter.chapter.nameKey),
                            onTap: chapter == currentChapter ? null : () => onToggle(chapter.chapter.number),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: ChapterTrail(
                          chapter: chapter,
                          data: overview.data,
                          currentNodeId: current?.node.id,
                          onTap: onOpen,
                        ),
                      ),
                    ] else
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                          child: _CollapsedChapter(
                            chapter: chapter,
                            previous: path.chapters
                                .where((c) => c.chapter.number == chapter.chapter.number - 1)
                                .firstOrNull,
                            data: overview.data,
                            onTap: chapter.isUnlocked ? () => onToggle(chapter.chapter.number) : null,
                          ),
                        ),
                      ),
                  SliverToBoxAdapter(child: SizedBox(height: current == null ? 24 : 96)),
                ],
              ),
              if (current != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: GwentButton(
                    label: l10n.campaignContinue(overview.data.text(current.node.opponent.nameKey)),
                    fontSize: 20,
                    maxLines: 2,
                    onPressed: () => onOpen(current),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GwentColors.rowSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: GwentColors.brass),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: GwentColors.textPrimary,
                    ),
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: GwentColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Залипающая строка главы.
class _ChapterStrip extends SliverPersistentHeaderDelegate {
  const _ChapterStrip({required this.chapter, required this.data, required this.l10n});

  final ChapterView chapter;
  final CampaignData data;
  final AppLocalizations l10n;

  @override
  double get minExtent => 36;

  @override
  double get maxExtent => 36;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox(
    height: maxExtent,
    child: _ChapterStripView(chapter: chapter, data: data, l10n: l10n),
  );

  @override
  bool shouldRebuild(_ChapterStrip old) => old.chapter != chapter || old.l10n != l10n;
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter, required this.name, required this.onTap});

  final ChapterView chapter;
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: GwentColors.rowSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GwentColors.brass),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  CampaignLabel(l10n.campaignChapterNumber(chapter.chapter.number).toUpperCase()),
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: GwentText.cormorant,
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      height: 1.05,
                      color: GwentColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${chapter.passedCount}',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                    height: 1,
                    color: GwentColors.gold,
                  ),
                ),
                Text(
                  l10n.campaignOutOf(chapter.totalCount),
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontSize: 12,
                    color: GwentColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return onTap == null ? card : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card);
  }
}

/// Свёрнутая глава строкой: пройдена, закрыта с причиной или ждёт выпуска.
class _CollapsedChapter extends StatelessWidget {
  const _CollapsedChapter({required this.chapter, required this.previous, required this.data, required this.onTap});

  final ChapterView chapter;
  final ChapterView? previous;
  final CampaignData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (done, total) = chapter.stars;
    final note = chapter.isComingSoon
        ? l10n.campaignChapterSoon
        : !chapter.isUnlocked
        ? l10n.campaignChapterLocked(previous?.chapter.number ?? 1)
        : l10n.campaignChapterCleared(done, total);
    final row = DecoratedBox(
      decoration: BoxDecoration(
        color: GwentColors.surfaceSunken,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GwentColors.panelLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 12,
          children: [
            SizedBox.square(
              dimension: 36,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: GwentColors.line),
                ),
                child: Center(
                  child: Text(
                    '${chapter.chapter.number}',
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: GwentText.cormorant,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: GwentColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.text(chapter.chapter.nameKey),
                    style: TextStyle(
                      fontFamily: GwentText.cormorant,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: onTap == null ? GwentColors.disabledText : GwentColors.textPrimary,
                    ),
                  ),
                  Text(
                    note,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontSize: 14,
                      color: GwentColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.expand_more, color: GwentColors.textSecondary),
          ],
        ),
      ),
    );
    return onTap == null ? row : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }
}

class _ChapterStripView extends StatelessWidget {
  const _ChapterStripView({required this.chapter, required this.data, required this.l10n});

  final ChapterView chapter;
  final CampaignData data;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (done, total) = chapter.stars;
    final name = data.text(chapter.chapter.nameKey);
    return ColoredBox(
      color: const Color(0xF21A120B),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: CampaignLabel(
                l10n.campaignChapterStrip(chapter.chapter.number, name).toUpperCase(),
                color: GwentColors.gold,
              ),
            ),
            Text(
              total == 0
                  ? l10n.campaignChapterProgress(chapter.passedCount, chapter.totalCount)
                  : l10n.campaignChapterProgressStars(chapter.passedCount, chapter.totalCount, done, total),
              textScaler: TextScaler.noScaling,
              style: const TextStyle(fontFamily: GwentText.alegreya, fontSize: 13, color: GwentColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
