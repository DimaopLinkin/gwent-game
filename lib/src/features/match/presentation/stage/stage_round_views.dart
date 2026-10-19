import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/rolling_number.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/banner_layer.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/field/round_summary.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_frame.dart';

/// Плашка итога раунда (макет 13, шаг 3): полоса баннера с исходом и счётом, под ней строки способностей фракций.
///
/// Поле под плашкой остаётся видимым: полоса занимает 176 pt по высоте. [item] несёт масштаб по высоте и
/// непрозрачность; плашка стоит там, где её поставил слой эффектов.
class RoundPlaqueView extends StatelessWidget {
  /// Создаёт плашку для [item].
  const RoundPlaqueView({super.key, required this.item, required this.roster, required this.content});

  /// Кадр плашки.
  final PlaqueItem item;

  /// Участники партии: в hot-seat победителя называют по имени.
  final MatchRoster roster;

  /// Названия и гербы фракций.
  final FieldContent content;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = item.summary;
    final outcome = summary.outcome;
    final title = switch (outcome) {
      RoundOutcome.draw => l10n.summaryDraw,
      _ when roster.hotSeat => l10n.summaryWinnerHot(
        roster.name(outcome == RoundOutcome.win ? summary.mineSeat : summary.mineSeat.opponent, l10n),
      ),
      RoundOutcome.win => l10n.summaryYouWon,
      RoundOutcome.loss => l10n.summaryOpponentWon,
    };
    final (titleColor, ruleColor) = switch (outcome) {
      RoundOutcome.win => (GwentColors.goldHighlight, GwentColors.gold),
      RoundOutcome.loss => (GwentColors.textTertiary, GwentColors.brass),
      RoundOutcome.draw => (GwentColors.textPrimary, GwentColors.brass),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Opacity(
          opacity: item.alpha.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(1, item.scaleY, 1),
            child: MatchBannerStrip(
              weight: BannerWeight.round,
              title: title,
              titleColor: titleColor,
              ruleColor: ruleColor,
              titleSize: 34,
              subtitle: '${summary.scoreMine} : ${summary.scoreOpponent}',
            ),
          ),
        ),
        for (var k = 0; k < summary.marks.length; k++)
          if (k < item.marks.length && item.marks[k] > 0)
            Opacity(
              opacity: item.marks[k].clamp(0.0, 1.0),
              child: _MarkRow(mark: summary.marks[k], roster: roster, content: content),
            ),
      ],
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({required this.mark, required this.roster, required this.content});

  final FactionMark mark;
  final MatchRoster roster;
  final FieldContent content;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = switch (mark.kind) {
      FactionMarkKind.extraCard => l10n.summaryMarkExtraCard,
      FactionMarkKind.unitStays => l10n.summaryMarkUnitStays,
      FactionMarkKind.wonTie => l10n.summaryMarkWonTie,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: GwentColors.bg.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: GwentColors.brass),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            spacing: 10,
            children: [
              if (content.faction(mark.faction).crest case final crest?) GwentIconView(crest, size: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      roster.name(mark.seat, l10n).toUpperCase(),
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: GwentText.alegreya,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                        height: 1,
                        letterSpacing: 10.5 * 0.08,
                        color: GwentColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${content.factionName(mark.faction)}: $text',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: GwentText.alegreya,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.15,
                        color: GwentColors.goldHighlight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Плашка исхода матча (макет 13, конец матча): «Победа», «Поражение» или «Ничья» и счёт выигранных раундов.
class MatchBannerView extends StatelessWidget {
  /// Создаёт плашку для [item].
  const MatchBannerView({super.key, required this.item, required this.roster});

  /// Кадр плашки.
  final MatchBannerItem item;

  /// Участники партии: в hot-seat победителя называют по имени, потому что телефон держат двое.
  final MatchRoster roster;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final winner = item.winner;
    final (title, titleColor, ruleColor) = switch (item.outcome) {
      _ when roster.hotSeat && winner != null => (
        l10n.matchResultWinnerHot(roster.name(winner, l10n)),
        GwentColors.goldHighlight,
        GwentColors.gold,
      ),
      RoundOutcome.win => (l10n.matchFinishedWin, GwentColors.goldHighlight, GwentColors.gold),
      RoundOutcome.loss => (l10n.matchFinishedLose, GwentColors.debuff, GwentColors.brass),
      RoundOutcome.draw => (l10n.matchFinishedDraw, GwentColors.textPrimary, GwentColors.brass),
    };
    return Opacity(
      opacity: item.alpha.clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(1, item.scaleY, 1),
        child: MatchBannerStrip(
          weight: BannerWeight.round,
          title: title,
          titleColor: titleColor,
          ruleColor: ruleColor,
          subtitle: l10n.matchResultRounds(item.roundsMine, item.roundsTheirs),
        ),
      ),
    );
  }
}

/// Счёт «мой : соперника» в центральной полосе во время подсчёта рядов.
class CountLabel extends StatelessWidget {
  /// Создаёт подпись для [item].
  const CountLabel({super.key, required this.item});

  /// Кадр подсчёта.
  final CountItem item;

  @override
  Widget build(BuildContext context) {
    TextStyle style({required bool mine}) => TextStyle(
      fontFamily: GwentText.cormorant,
      fontWeight: FontWeight.w700,
      fontSize: 20,
      height: 1.1,
      color: switch (item.winner) {
        RoundOutcome.win when mine => GwentColors.goldHighlight,
        RoundOutcome.loss when !mine => GwentColors.goldHighlight,
        RoundOutcome.draw => GwentColors.goldHighlight,
        null => GwentColors.textPrimary,
        _ => GwentColors.textSecondary,
      },
    );
    return Opacity(
      opacity: item.alpha.clamp(0.0, 1.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: GwentColors.bg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: GwentColors.brass),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              RollingNumber(item.mine, style: style(mine: true)),
              Text(
                ':',
                textScaler: TextScaler.noScaling,
                style: style(mine: true).copyWith(color: GwentColors.muted),
              ),
              RollingNumber(item.theirs, style: style(mine: false)),
            ],
          ),
        ),
      ),
    );
  }
}
