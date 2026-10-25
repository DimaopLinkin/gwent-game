import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/faction_medallion.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/components/status_tag.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/match_history/presentation/history_cubit.dart';
import 'package:gwent/src/features/match_history/presentation/history_state.dart';

/// История партий: сыгранные партии, сначала последние, с итогом, счётом и режимом. Партию с реплеем можно открыть.
///
/// Партии, сыгранные до появления реплеев, остаются только строкой истории.
class HistoryScreen extends StatelessWidget {
  /// Создаёт экран; [onOpen] открывает реплей партии с идентификатором, [onBack] выходит в меню.
  const HistoryScreen({super.key, required this.onOpen, required this.onBack});

  /// Игрок открыл реплей партии с идентификатором `recordId`.
  final ValueChanged<String> onOpen;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: Column(
        children: [
          ScreenHeader(eyebrow: l10n.historyEyebrow, title: l10n.historyTitle, titleSize: 34, onBack: onBack),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
              child: BlocBuilder<HistoryCubit, HistoryState>(
                builder: (context, state) => switch (state) {
                  HistoryLoading() => const GameLoader(),
                  HistoryFailed() => _Message(l10n.historyLoadFailed),
                  HistoryLoaded(:final records) when records.isEmpty => _Message(l10n.historyEmpty),
                  HistoryLoaded(:final records, :final factions) => ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _MatchRow(record: records[index], factions: factions, onOpen: onOpen),
                  ),
                },
              ),
            ),
          ),
        ],
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

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.record, required this.factions, required this.onOpen});

  final MatchRecord record;
  final Map<String, HistoryFaction> factions;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mine = factions[record.playerFactionId];
    final theirs = factions[record.opponentFactionId];
    final (outcome, outcomeColor) = switch (record.outcome) {
      MatchOutcome.victory => (l10n.historyOutcomeVictory, GwentColors.buff),
      MatchOutcome.defeat => (l10n.historyOutcomeDefeat, GwentColors.errorText),
      MatchOutcome.draw => (l10n.historyOutcomeDraw, GwentColors.textSecondary),
    };
    final mode = switch (record.mode) {
      MatchMode.hotSeat => l10n.historyModeHotSeat,
      MatchMode.ai => l10n.historyModeAi,
      MatchMode.wifi => l10n.historyModeWifi,
      MatchMode.bluetooth => l10n.historyModeBluetooth,
      MatchMode.server => l10n.historyModeOnline,
    };
    final name = record.opponentName;
    final local = record.finishedAt.toLocal();
    final versus = mine == null || theirs == null ? null : l10n.historyVersus(mine.name, theirs.name);
    final summary = [
      outcome,
      ?versus,
      l10n.historyRounds(record.roundsWon, record.roundsLost),
    ].join(', ');
    final hasReplay = record.hasReplay;

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: GwentColors.rowSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GwentColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 12,
          children: [
            if (mine != null)
              FactionMedallion(faction: GwentFaction.fromKey(mine.key), size: 44, crestSize: 22, glow: false),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusTag(
                        outcome.toUpperCase(),
                        background: outcomeColor.withValues(alpha: 0.16),
                        color: outcomeColor,
                        ring: outcomeColor.withValues(alpha: 0.5),
                      ),
                      Text(
                        l10n.historyRounds(record.roundsWon, record.roundsLost),
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          height: 1,
                          color: GwentColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (versus != null) _Line(versus, color: GwentColors.textPrimary, size: 15),
                  _Line(name == null ? mode : l10n.historyModeWithOpponent(mode, name)),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(child: _Line(l10n.historyWhen(local, local))),
                      if (hasReplay)
                        StatusTag(
                          l10n.historyWatch.toUpperCase(),
                          background: GwentColors.gold,
                          color: GwentColors.onGold,
                        )
                      else
                        Text(
                          l10n.historyNoReplay,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: GwentText.alegreya,
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                            color: GwentColors.disabledText,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!hasReplay) return content;
    return Semantics(
      button: true,
      label: l10n.historyOpenSemantics(summary),
      excludeSemantics: true,
      onTap: () => onOpen(record.id),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onOpen(record.id), child: content),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text, {this.color = GwentColors.textTertiary, this.size = 14});

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    textScaler: TextScaler.noScaling,
    style: TextStyle(
      fontFamily: GwentText.alegreya,
      fontWeight: FontWeight.w500,
      fontSize: size,
      height: 1.2,
      color: color,
    ),
  );
}
