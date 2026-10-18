import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_labels.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/start/start_parts.dart';
import 'package:gwent_engine/gwent_engine.dart' show PlayerView, Seat;

/// Итог матча (макет 5, раздел 3): «Победа», «Поражение» или «Ничья», счёт раундов, таблица раундов, лидеры и
/// фракции обоих игроков, кнопки «Реванш» и «В меню».
///
/// «Реванш» доступен только для местной партии ([onRematch] `null` — кнопки нет). В hot-seat колонки названы по
/// игрокам, а под заголовком сказано, кто победил.
class MatchResultView extends StatelessWidget {
  /// Создаёт экран по итоговой проекции [view].
  const MatchResultView({super.key, required this.view, required this.roster, required this.onExit, this.onRematch});

  /// Итоговая проекция.
  final PlayerView view;

  /// Участники партии.
  final MatchRoster roster;

  /// Выход в меню.
  final VoidCallback onExit;

  /// Реванш; `null` — сыграть заново нельзя.
  final VoidCallback? onRematch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = FieldContent(content: roster.content, l10n: l10n);
    final me = view.viewer;
    final winner = view.outcome?.winner;
    final hotSeat = roster.hotSeat;
    final draw = winner == null;
    final won = winner == me;
    final (title, titleColor, glow, backdrop) = draw
        ? (l10n.matchFinishedDraw, GwentColors.textPrimary, false, const Color(0x29A09682))
        : (won || hotSeat)
        ? (l10n.matchFinishedWin, GwentColors.goldHighlight, true, const Color(0x4DC8963C))
        : (l10n.matchFinishedLose, GwentColors.defeat, false, const Color(0x57702822));
    final wins = {
      for (final seat in Seat.values) seat: view.history.where((result) => result.winner == seat).length,
    };
    final rounds = roster.content.rules.crystals + 1;
    return StartBackdrop(
      base: won || draw || hotSeat ? const Color(0xFF0F0C09) : const Color(0xFF0E0B09),
      topGlow: backdrop,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - 100),
          child: Column(
            children: [
              Eyebrow(l10n.matchResultEyebrow, size: 14, align: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w700,
                  fontSize: 62,
                  height: 1,
                  letterSpacing: 62 * 0.02,
                  color: titleColor,
                  shadows: glow ? const [Shadow(color: Color(0x59E6C67E), blurRadius: 40)] : null,
                ),
              ),
              if (hotSeat && winner != null) ...[
                const SizedBox(height: 8),
                StartBody(
                  l10n.matchResultWinnerHot(roster.name(winner, l10n)),
                  size: 17,
                  color: GwentColors.textTertiary,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                l10n.matchResultRounds(wins[me] ?? 0, wins[me.opponent] ?? 0),
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  height: 1,
                  letterSpacing: 18 * 0.08,
                  color: GwentColors.textTertiary,
                ),
              ),
              const SizedBox(height: 26),
              _Table(view: view, roster: roster, rounds: rounds),
              const SizedBox(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 14,
                children: [
                  for (final seat in [me, me.opponent])
                    Expanded(
                      child: _Player(seat: seat, roster: roster, content: content),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                spacing: 12,
                children: [
                  if (onRematch != null)
                    Expanded(
                      flex: 12,
                      child: GwentButton(
                        label: l10n.matchResultRematch,
                        height: 56,
                        fontSize: 24,
                        onPressed: onRematch,
                      ),
                    ),
                  Expanded(
                    flex: 10,
                    child: GwentButton(
                      label: l10n.matchExit,
                      style: GwentButtonStyle.secondary,
                      height: 56,
                      onPressed: onExit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.view, required this.roster, required this.rounds});

  final PlayerView view;
  final MatchRoster roster;
  final int rounds;

  static const TextStyle _head = TextStyle(
    fontFamily: GwentText.cormorant,
    fontWeight: FontWeight.w700,
    fontSize: 11.5,
    height: 1,
    letterSpacing: 11.5 * 0.06,
    color: GwentColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final me = view.viewer;
    String nameOf(Seat seat) => roster.name(seat, l10n);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0x8C0A0806),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: GwentColors.line, spreadRadius: 1)],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 30,
            child: _row(
              Text(l10n.matchResultColumnRound.toUpperCase(), style: _head, textScaler: TextScaler.noScaling),
              Text(
                nameOf(me).toUpperCase(),
                style: _head,
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
              Text(
                nameOf(me.opponent).toUpperCase(),
                style: _head,
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
              Text(
                l10n.matchResultColumnWinner.toUpperCase(),
                style: _head,
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.end,
                maxLines: 1,
              ),
            ),
          ),
          for (var i = 0; i < rounds; i++) _roundRow(l10n, i, me),
        ],
      ),
    );
  }

  Widget _roundRow(AppLocalizations l10n, int index, Seat me) {
    final result = view.history.where((result) => result.round == index + 1).firstOrNull;
    final mine = result?.scores[me];
    final theirs = result?.scores[me.opponent];
    final winner = result?.winner;
    const win = GwentColors.goldHighlight;
    const muted = GwentColors.muted;
    Color scoreColor(Seat seat) => result == null
        ? muted
        : winner == null
        ? GwentColors.textPrimary
        : winner == seat
        ? win
        : GwentColors.loserText;
    Widget score(int? value, Seat seat) => Text(
      value == null ? '—' : '$value',
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: GwentText.alegreya,
        fontWeight: FontWeight.w800,
        fontSize: 22,
        height: 1,
        fontFeatures: GwentText.numbers,
        color: scoreColor(seat),
      ),
    );
    final winnerText = result == null
        ? '—'
        : winner == null
        ? l10n.matchFinishedDraw
        : roster.name(winner, l10n);
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: GwentColors.surfaceRaised)),
        ),
        child: _row(
          Text(
            l10n.matchResultRound(index + 1),
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: GwentText.alegreya,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              height: 1,
              color: GwentColors.textTertiary,
            ),
          ),
          score(mine, me),
          score(theirs, me.opponent),
          Text(
            winnerText,
            maxLines: 1,
            textAlign: TextAlign.end,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1,
              letterSpacing: 15 * 0.05,
              color: result == null
                  ? muted
                  : winner == me
                  ? win
                  : winner == null
                  ? GwentColors.textSecondary
                  : GwentColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(Widget round, Widget mine, Widget theirs, Widget winner) => Row(
    spacing: 8,
    children: [
      SizedBox(width: 60, child: round),
      SizedBox(width: 50, child: Center(child: mine)),
      SizedBox(width: 88, child: Center(child: theirs)),
      Expanded(
        child: Align(alignment: Alignment.centerRight, child: winner),
      ),
    ],
  );
}

class _Player extends StatelessWidget {
  const _Player({required this.seat, required this.roster, required this.content});

  final Seat seat;
  final MatchRoster roster;
  final FieldContent content;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final player = roster.player(seat);
    final faction = content.faction(player.faction);
    final leader = content.leaderFace(player.leader);
    return Column(
      spacing: 10,
      children: [
        SizedBox(
          width: CardSize.hand.metrics.width,
          height: CardSize.hand.metrics.height,
          child: GwentCard(face: leader, size: CardSize.hand),
        ),
        Eyebrow(roster.name(seat, l10n), size: 12, align: TextAlign.center),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 6,
          children: [
            if (faction.crest case final crest?) GwentIconView(crest, size: 24),
            Flexible(
              child: Text(
                content.factionName(player.faction),
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  height: 1.1,
                  color: GwentColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        StartBody(leader.name, size: 14),
      ],
    );
  }
}
