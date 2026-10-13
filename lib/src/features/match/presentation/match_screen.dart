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
import 'package:gwent_engine/gwent_engine.dart' hide Row;

/// Экран партии: выбор режима и колод, передача телефона, пересдача, поле и итог.
///
/// Показывает то, что говорит `MatchBloc`; выбор игрока на поле держит `FieldCubit`, он получает состояние партии
/// отсюда же. Экраны вокруг поля (выбор колод, передача телефона, пересдача, итог) простые и без макетов: макеты
/// старта партии и итогов ещё в работе.
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
      MatchHandover(:final next) => MatchPanel(
        title: l10n.matchHandoverTitle(next.index + 1),
        body: l10n.matchHandoverBody,
        actions: [
          (label: l10n.matchHandoverReady, onPressed: () => bloc.add(const MatchHandoverAccepted()), primary: true),
        ],
      ),
      MatchInProgress(:final view, :final content) => switch (view) {
        PlayerView(phase: MatchPhase.choosingFirstPlayer) => MatchFirstPlayerStage(view: view, onIntent: submit),
        PlayerView(phase: MatchPhase.redraw) => MatchRedrawStage(view: view, content: content, onIntent: submit),
        _ => FieldView(view: view, content: content, onIntent: submit, confirmPass: confirmPass),
      },
      MatchFinished(:final view) => MatchFinishedStage(view: view, onExit: onExit),
      MatchCrashed() => MatchPanel(
        title: l10n.matchCrashed,
        actions: [(label: l10n.matchExit, onPressed: onExit, primary: true)],
      ),
    };
  }
}
