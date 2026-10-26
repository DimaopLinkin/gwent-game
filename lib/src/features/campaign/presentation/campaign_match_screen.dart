import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_match_cubit.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_match_state.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_reward_view.dart';
import 'package:gwent/src/features/haptics/application/play_haptic.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_screen.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match/presentation/match_stages.dart';
import 'package:gwent/src/features/match/presentation/overlays/match_result_view.dart';
import 'package:gwent/src/features/sound/application/play_sound.dart';

/// Партия узла кампании (ADR 0033): обычный экран партии против бота и итог с наградой.
///
/// Партию показывает `MatchScreen`, который о кампании ничего не знает; итог кампании приходит от его хука конца
/// партии и ложится на лист итога: «Награда уже получена», «Узел остаётся открытым» или экран награды поверх.
/// Ждёт `CampaignMatchCubit` выше по дереву.
class CampaignMatchScreen extends StatelessWidget {
  /// Создаёт экран.
  const CampaignMatchScreen({
    super.key,
    required this.startMatch,
    required this.recordFinishedMatch,
    required this.onExit,
    required this.onNext,
    required this.onChangeDeck,
    required this.onBuildDeck,
    this.onSettings,
    this.onHowToPlay,
    this.confirmPass = false,
    this.hints = false,
    this.animationScale = 1,
    this.sound,
    this.haptic,
  });

  /// Сценарий начала партии: держателю партии он нужен для устройства.
  final StartMatch startMatch;

  /// Сценарий записи партии в историю.
  final RecordFinishedMatch recordFinishedMatch;

  /// Выход на тропу.
  final VoidCallback onExit;

  /// «Дальше»: идти в узел с этим идентификатором.
  final ValueChanged<String> onNext;

  /// «Сменить колоду» для узла с этим идентификатором.
  final ValueChanged<String> onChangeDeck;

  /// Собрать колоду в конструкторе кампании.
  final VoidCallback onBuildDeck;

  /// Открыть настройки из паузы.
  final VoidCallback? onSettings;

  /// Открыть справочник из паузы.
  final VoidCallback? onHowToPlay;

  /// Спрашивать подтверждение паса диалогом.
  final bool confirmPass;

  /// Подсказки в центральной полосе.
  final bool hints;

  /// Доля обычных длительностей анимаций карт.
  final double animationScale;

  /// Звуки партии.
  final PlaySound? sound;

  /// Вибрация партии.
  final PlayHaptic? haptic;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<CampaignMatchCubit, CampaignMatchState>(
      // Итог партии приходит позже самой партии: держатели партии при этом не пересоздаются.
      buildWhen: (previous, current) => previous.runtimeType != current.runtimeType,
      builder: (context, state) => switch (state) {
        CampaignMatchLoading() => const Scaffold(
          backgroundColor: GwentColors.bg,
          body: SafeArea(child: Center(child: GameLoader())),
        ),
        CampaignMatchNeedsDeck() => Scaffold(
          backgroundColor: GwentColors.bg,
          body: SafeArea(
            child: MatchPanel(
              title: l10n.campaignNoDeckTitle,
              actions: [
                (label: l10n.campaignBuildDeck, onPressed: onBuildDeck, primary: true),
                (label: l10n.campaignToTrail, onPressed: onExit, primary: false),
              ],
            ),
          ),
        ),
        CampaignMatchUnavailable() => Scaffold(
          backgroundColor: GwentColors.bg,
          body: SafeArea(
            child: MatchPanel(
              title: l10n.campaignMatchUnavailable,
              actions: [(label: l10n.campaignToTrail, onPressed: onExit, primary: true)],
            ),
          ),
        ),
        final CampaignMatchPlaying playing => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => MatchBloc(startMatch, recordFinishedMatch)..add(MatchStartRequested(playing.request)),
            ),
            BlocProvider(
              create: (_) => FieldCubit(sound: sound, haptic: haptic),
            ),
          ],
          child: BlocListener<MatchBloc, MatchScreenState>(
            listenWhen: (previous, current) => current is MatchStarting,
            listener: (context, state) => context.read<CampaignMatchCubit>().matchStarted(),
            child: MatchScreen(
              onExit: onExit,
              onEditDeck: (_) {},
              onSettings: onSettings,
              onHowToPlay: onHowToPlay,
              confirmPass: confirmPass,
              hints: hints,
              animationScale: animationScale,
              resultBuilder: (context, finished) => _Result(
                finished: finished,
                onExit: onExit,
                onNext: onNext,
                onChangeDeck: onChangeDeck,
                onBuildDeck: onBuildDeck,
              ),
            ),
          ),
        ),
      },
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.finished,
    required this.onExit,
    required this.onNext,
    required this.onChangeDeck,
    required this.onBuildDeck,
  });

  final MatchFinished finished;
  final VoidCallback onExit;
  final ValueChanged<String> onNext;
  final ValueChanged<String> onChangeDeck;
  final VoidCallback onBuildDeck;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<MatchBloc>();
    return BlocBuilder<CampaignMatchCubit, CampaignMatchState>(
      builder: (context, state) {
        if (state is! CampaignMatchPlaying) return const SizedBox.shrink();
        final result = state.result;
        final won = result is CampaignWon && !result.isEmpty ? result : null;
        final note = switch ((result, state.resultFailed)) {
          (_, true) => l10n.campaignResultFailed,
          (CampaignNoReward(), _) => l10n.campaignDefeatNote,
          (final CampaignWon repeat, _) when repeat.isEmpty =>
            '${l10n.campaignRewardAlready}\n${repeat.bonusMet ? l10n.campaignRepeatBonusNote : l10n.campaignRepeatNote}',
          _ => null,
        };
        return Stack(
          fit: StackFit.expand,
          children: [
            MatchResultView(
              view: finished.view,
              roster: finished.roster,
              onExit: onExit,
              onRematch: finished.canRematch ? () => bloc.add(const MatchRematchRequested()) : null,
              onChangeDeck: result is CampaignNoReward ? () => onChangeDeck(state.node.id) : null,
              exitLabel: l10n.campaignToTrail,
              changeDeckLabel: l10n.campaignChangeDeck,
              note: note == null ? null : _Note(text: note),
              field: FieldView(
                view: finished.view,
                content: finished.roster.content,
                roster: finished.roster,
                onIntent: (_) {},
                readOnly: true,
              ),
            ),
            if (won != null)
              CampaignRewardView(
                won: won,
                data: state.data,
                onNext: onNext,
                onTrail: onExit,
                onBuildDeck: onBuildDeck,
              ),
          ],
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontFamily: GwentText.alegreya,
      fontStyle: FontStyle.italic,
      fontSize: 16,
      height: 1.25,
      color: GwentColors.textTertiary,
    ),
  );
}
