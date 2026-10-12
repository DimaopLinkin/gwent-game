import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/life_gems.dart';
import 'package:gwent/src/core/presentation/components/score_badge.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Состояние плашки игрока.
enum PlayerPlateStatus {
  /// Не его ход.
  idle,

  /// Его ход: золотая рамка, свечение и метка «Ваш ход».
  active,

  /// Спасовал: метка «Пас» и приглушённый портрет.
  passed,
}

/// Плашка игрока (макет дизайн-системы, `playerPlate`): портрет с гербом фракции, имя, фракция, число карт в руке,
/// камни-жизни и общий счёт. Ширина — вся доступная (358 pt на экране 390 pt), имя в одну строку с многоточием,
/// метка состояния переносится под имя.
class PlayerPlate extends StatelessWidget {
  /// Создаёт плашку.
  const PlayerPlate({
    super.key,
    required this.name,
    required this.factionName,
    required this.faction,
    required this.handCount,
    required this.lifeRemaining,
    required this.score,
    this.lifeTotal = 2,
    this.status = PlayerPlateStatus.idle,
    this.leading = false,
  });

  /// Имя игрока.
  final String name;

  /// Название фракции.
  final String factionName;

  /// Фракция: герб на портрете.
  final GwentFaction faction;

  /// Сколько карт в руке.
  final int handCount;

  /// Сколько камней-жизней осталось.
  final int lifeRemaining;

  /// Сколько камней-жизней было в начале партии.
  final int lifeTotal;

  /// Общий счёт.
  final int score;

  /// Состояние.
  final PlayerPlateStatus status;

  /// Игрок ведёт по очкам.
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = status == PlayerPlateStatus.active;
    final passed = status == PlayerPlateStatus.passed;
    final label = switch (status) {
      PlayerPlateStatus.active => l10n.playerPlateYourTurn,
      PlayerPlateStatus.passed => l10n.playerPlatePassed,
      PlayerPlateStatus.idle => null,
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GwentColors.surfaceRaised, GwentColors.surface],
        ),
        border: Border.all(color: active ? GwentColors.gold : GwentColors.line),
        borderRadius: BorderRadius.circular(GwentSpace.radiusM),
        boxShadow: [
          if (active) const BoxShadow(color: Color(0x38C8A35B), blurRadius: 20),
          const BoxShadow(color: Color(0x80080502), offset: Offset(0, 4), blurRadius: 12),
        ],
      ),
      child: Row(
        spacing: 12,
        children: [
          Opacity(
            opacity: passed ? 0.75 : 1,
            child: _Portrait(faction: faction),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 5,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w600,
                          fontSize: 19,
                          height: 1.1,
                          color: passed ? GwentColors.textSecondary : GwentColors.textPrimary,
                        ),
                      ),
                    ),
                    if (label != null) _StatusTag(label: label, passed: passed),
                  ],
                ),
                Text(
                  factionName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1,
                    color: GwentColors.textSecondary,
                  ),
                ),
                Row(
                  spacing: 12,
                  children: [
                    Semantics(
                      label: l10n.playerPlateHandCount(handCount),
                      excludeSemantics: true,
                      child: Row(
                        spacing: 4,
                        children: [
                          const GwentIconView(GwentIcon.iconHand, size: 16, color: GwentColors.textSecondary),
                          Text(
                            '$handCount',
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: GwentText.alegreya,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              height: 1,
                              fontFeatures: GwentText.numbers,
                              color: GwentColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LifeGems(remaining: lifeRemaining, total: lifeTotal, size: 14, gap: 5),
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            label: l10n.playerPlateScoreSemantics(score),
            excludeSemantics: true,
            child: TotalScoreBadge(score: score, leading: leading, diameter: 48),
          ),
        ],
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.faction});

  final GwentFaction faction;

  @override
  Widget build(BuildContext context) => Container(
    width: 50,
    height: 50,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: GwentColors.artPlaceholder,
      borderRadius: BorderRadius.all(Radius.circular(GwentSpace.radiusS)),
      boxShadow: [BoxShadow(color: GwentColors.brass, spreadRadius: 1)],
    ),
    child: switch (faction.crest) {
      final crest? => GwentIconView(crest, size: 30),
      null => const GwentIconView(GwentIcon.iconLeader, size: 24),
    },
  );
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.passed});

  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: passed ? GwentColors.parchment : GwentColors.gold,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: Text(
        label,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: GwentText.cormorant,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          height: 1,
          letterSpacing: 0.88,
          color: passed ? GwentColors.onParchment : GwentColors.onGold,
        ),
      ),
    ),
  );
}
