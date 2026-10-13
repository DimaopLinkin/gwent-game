import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/life_gems.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/start/start_parts.dart';

/// Итог раунда поверх поля (макет 5, раздел 2): счёт, камни жизни и сработавшие способности фракций.
///
/// Затемняет поле на 84 %. Победитель выделен золотом, проигравший приглушён; у проигравшего камень вспыхивает,
/// трескается и гаснет. Нажатие в любом месте закрывает итог ([onDismissed]).
class RoundSummaryView extends StatelessWidget {
  /// Создаёт итог раунда [summary] для партии [roster].
  const RoundSummaryView({super.key, required this.summary, required this.roster, required this.onDismissed});

  /// Итог.
  final RoundSummary summary;

  /// Участники партии.
  final MatchRoster roster;

  /// Игрок нажал «продолжить».
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = FieldContent(content: roster.content, l10n: l10n);
    final mine = summary.mineSeat;
    final outcome = summary.outcome;
    const win = GwentColors.goldHighlight;
    const lose = GwentColors.loserText;
    const draw = GwentColors.textPrimary;
    final (mineColor, theirColor) = switch (outcome) {
      RoundOutcome.win => (win, lose),
      RoundOutcome.loss => (lose, win),
      RoundOutcome.draw => (draw, draw),
    };
    final title = switch (outcome) {
      RoundOutcome.draw => l10n.summaryDraw,
      _ when roster.hotSeat => l10n.summaryWinnerHot(
        roster.name(outcome == RoundOutcome.win ? mine : mine.opponent, l10n),
      ),
      RoundOutcome.win => l10n.summaryYouWon,
      RoundOutcome.loss => l10n.summaryOpponentWon,
    };
    final titleColor = switch (outcome) {
      RoundOutcome.win => win,
      RoundOutcome.loss => GwentColors.textTertiary,
      RoundOutcome.draw => draw,
    };
    final total = roster.content.rules.crystals;
    return Semantics(
      container: true,
      button: true,
      onTap: onDismissed,
      label: l10n.summaryContinue,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismissed,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xD60A0806)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 60, 22, 24),
            child: Column(
              children: [
                Eyebrow(l10n.summaryEyebrow(summary.round), size: 14, align: TextAlign.center),
                const SizedBox(height: 12),
                StartTitle(title, size: 40, color: titleColor, align: TextAlign.center),
                const SizedBox(height: 16),
                const SizedBox(width: 200, child: _Ornament()),
                const SizedBox(height: 26),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SideColumn(
                        score: summary.scoreMine,
                        color: mineColor,
                        glow: outcome == RoundOutcome.win,
                        faction: content.faction(summary.mineFaction),
                        name: roster.name(mine, l10n),
                        crystals: summary.crystalsMine,
                        total: total,
                        breaking: summary.lostMine,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: Text(
                        ':',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 52,
                          height: 1,
                          color: GwentColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _SideColumn(
                        score: summary.scoreOpponent,
                        color: theirColor,
                        glow: outcome == RoundOutcome.loss,
                        faction: content.faction(summary.opponentFaction),
                        name: roster.name(mine.opponent, l10n),
                        crystals: summary.crystalsOpponent,
                        total: total,
                        breaking: summary.lostOpponent,
                      ),
                    ),
                  ],
                ),
                if (summary.marks.isNotEmpty) ...[
                  const SizedBox(height: 34),
                  _Marks(summary: summary, roster: roster, content: content),
                ],
                const Spacer(),
                Text(
                  l10n.summaryContinue,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    height: 1,
                    color: GwentColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      const Expanded(
        child: SizedBox(
          height: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x008C6A3F), GwentColors.brass])),
          ),
        ),
      ),
      Transform.rotate(
        angle: 0.7853981633974483,
        child: const SizedBox.square(
          dimension: 6,
          child: ColoredBox(color: GwentColors.gold),
        ),
      ),
      const Expanded(
        child: SizedBox(
          height: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [GwentColors.brass, Color(0x008C6A3F)])),
          ),
        ),
      ),
    ],
  );
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({
    required this.score,
    required this.color,
    required this.glow,
    required this.faction,
    required this.name,
    required this.crystals,
    required this.total,
    required this.breaking,
  });

  final int score;
  final Color color;
  final bool glow;
  final GwentFaction faction;
  final String name;
  final int crystals;
  final int total;
  final bool breaking;

  @override
  Widget build(BuildContext context) {
    final crest = faction.crest;
    return Column(
      spacing: 10,
      children: [
        Text(
          '$score',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: GwentText.cormorant,
            fontWeight: FontWeight.w700,
            fontSize: 84,
            height: 1,
            fontFeatures: const [FontFeature.liningFigures()],
            color: color,
            shadows: glow ? const [Shadow(color: Color(0x59E6C67E), blurRadius: 24)] : null,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 7,
          children: [
            if (crest != null) GwentIconView(crest, size: 24),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  height: 1,
                  letterSpacing: 15 * 0.06,
                  color: GwentColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 26,
          child: Semantics(
            label: context.l10n.lifeGemsSemantics(crystals, total),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                for (var i = 0; i < total; i++)
                  breaking && i == crystals ? BreakingGem(key: ValueKey(i)) : LifeGem(lost: i >= crystals, size: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Камень, который теряется на глазах: вспыхивает и пульсирует, затем гаснет и остаётся пустым гнездом.
class BreakingGem extends StatefulWidget {
  /// Создаёт камень; пока идёт анимация, показывается целый камень.
  const BreakingGem({super.key});

  /// Сколько длится потеря камня.
  static const Duration duration = Duration(milliseconds: 1400);

  @override
  State<BreakingGem> createState() => _BreakingGemState();
}

class _BreakingGemState extends State<BreakingGem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: BreakingGem.duration);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = _controller.value;
      // До 0,4 камень светится и растёт, до 0,7 трескается, дальше остаётся пустое гнездо.
      final lost = t >= 0.55;
      final pulse = t < 0.4 ? 1 + 0.3 * (t / 0.4) : (t < 0.7 ? 1.3 - 0.3 * ((t - 0.4) / 0.3) : 1.0);
      return Transform.scale(
        scale: pulse,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: t < 0.55 && t > 0
                ? [BoxShadow(color: GwentColors.goldHighlight.withValues(alpha: 0.6 * t / 0.55), blurRadius: 14)]
                : null,
          ),
          child: LifeGem(lost: lost, size: 24),
        ),
      );
    },
  );
}

class _Marks extends StatelessWidget {
  const _Marks({required this.summary, required this.roster, required this.content});

  final RoundSummary summary;
  final MatchRoster roster;
  final FieldContent content;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: GwentColors.bg,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: GwentColors.line, spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Eyebrow(l10n.summaryFactionAbilities, size: 12),
          ),
          for (final mark in summary.marks)
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: GwentColors.surfaceRaised)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  spacing: 12,
                  children: [
                    if (content.faction(mark.faction).crest case final crest?) GwentIconView(crest, size: 30),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 3,
                        children: [
                          Text(
                            roster.name(mark.seat, l10n).toUpperCase(),
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: GwentText.alegreya,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              height: 1,
                              letterSpacing: 11.5 * 0.08,
                              color: GwentColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${content.factionName(mark.faction)}: ${switch (mark.kind) {
                              FactionMarkKind.extraCard => l10n.summaryMarkExtraCard,
                              FactionMarkKind.unitStays => l10n.summaryMarkUnitStays,
                              FactionMarkKind.wonTie => l10n.summaryMarkWonTie,
                            }}',
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: GwentText.alegreya,
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              height: 1.2,
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
        ],
      ),
    );
  }
}
