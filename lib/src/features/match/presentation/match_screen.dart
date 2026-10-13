import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent/src/features/match/presentation/match_stages.dart';
import 'package:gwent/src/features/match/presentation/overlays/match_result_view.dart';
import 'package:gwent/src/features/match/presentation/start/first_player_view.dart';
import 'package:gwent/src/features/match/presentation/start/handover_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_intro_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_toss_view.dart';
import 'package:gwent/src/features/match/presentation/start/redraw_view.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Row;

/// Экран партии: от выбора колод до итога.
///
/// Показывает то, что говорит `MatchBloc`: знакомство, жребий, выбор Скоя'таэлей, передачу телефона, пересдачу, поле
/// и итог матча. Выбор игрока на поле, баннеры, итог раунда и паузу держит `FieldCubit`, он получает состояние
/// партии отсюда же. Выбор колод перед партией временный, без макета: его заменит экран выбора фракции.
class MatchScreen extends StatelessWidget {
  /// Создаёт экран; [onExit] уводит из партии в меню, [confirmPass] включает диалог подтверждения паса.
  const MatchScreen({super.key, required this.onExit, this.confirmPass = false});

  /// Выход из партии.
  final VoidCallback onExit;

  /// Спрашивать подтверждение паса диалогом; иначе пас нужно держать 1 с.
  final bool confirmPass;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GwentColors.bg,
    body: SafeArea(
      child: BlocConsumer<MatchBloc, MatchScreenState>(
        listener: (context, state) => context.read<FieldCubit>().onMatchState(state),
        builder: _stage,
      ),
    ),
  );

  Widget _stage(BuildContext context, MatchScreenState state) {
    final l10n = context.l10n;
    final bloc = context.read<MatchBloc>();
    void submit(Intent intent) => bloc.add(MatchIntentSubmitted(intent));
    return switch (state) {
      MatchIdle() => BlocBuilder<MatchSetupCubit, MatchSetupState>(
        builder: (context, setup) => MatchSetupStage(
          state: setup,
          cubit: context.read<MatchSetupCubit>(),
          onStart: (request) => bloc.add(MatchStartRequested(request)),
          onExit: onExit,
        ),
      ),
      MatchStarting() => const GameLoader(),
      MatchStartFailed() => MatchPanel(
        title: l10n.matchStartFailed,
        actions: [(label: l10n.matchExit, onPressed: onExit, primary: true)],
      ),
      MatchIntro(:final roster) => MatchIntroView(
        roster: roster,
        onFinished: () => bloc.add(const MatchIntroFinished()),
      ),
      MatchToss(:final roster, :final first, :final byChoice) => MatchTossView(
        roster: roster,
        first: first,
        byChoice: byChoice,
        onFinished: () => bloc.add(const MatchTossFinished()),
      ),
      MatchHandover(:final next, :final kind, :final roster) => MatchHandoverView(
        next: next,
        kind: kind,
        roster: roster,
        onReady: () => bloc.add(const MatchHandoverAccepted()),
      ),
      MatchInProgress(:final view, :final content, :final roster) => switch (view) {
        PlayerView(phase: MatchPhase.choosingFirstPlayer) => MatchFirstPlayerView(
          view: view,
          roster: roster,
          onIntent: submit,
        ),
        PlayerView(phase: MatchPhase.redraw, me: SideView(redrawDone: true)) => MatchRedrawWaitView(
          view: view,
          roster: roster,
        ),
        PlayerView(phase: MatchPhase.redraw) => MatchRedrawView(view: view, roster: roster, onIntent: submit),
        _ => FieldView(view: view, content: content, roster: roster, onIntent: submit, confirmPass: confirmPass),
      },
      MatchFinished(:final view, :final roster, :final canRematch) => MatchResultView(
        view: view,
        roster: roster,
        onExit: onExit,
        onRematch: canRematch ? () => bloc.add(const MatchRematchRequested()) : null,
      ),
      MatchCrashed() => MatchPanel(
        title: l10n.matchCrashed,
        actions: [(label: l10n.matchExit, onPressed: onExit, primary: true)],
      ),
    };
  }
}
