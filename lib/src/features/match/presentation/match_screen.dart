import 'dart:collection';

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match/presentation/match_stages.dart';
import 'package:gwent/src/features/match/presentation/overlays/match_result_view.dart';
import 'package:gwent/src/features/match/presentation/setup/match_setup_stage.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent/src/features/match/presentation/start/first_player_view.dart';
import 'package:gwent/src/features/match/presentation/start/handover_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_intro_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_toss_view.dart';
import 'package:gwent/src/features/match/presentation/start/redraw_view.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Row;

/// Экран партии: от выбора фракции и колоды до итога.
///
/// Показывает то, что говорит `MatchBloc`: знакомство, жребий, выбор Скоя'таэлей, передачу телефона, пересдачу, поле
/// и итог матча. Выбор игрока на поле, баннеры, итог раунда и паузу держит `FieldCubit`, он получает состояние
/// партии отсюда же. Выбор фракции, лидера и колоды перед партией (макет 7) держит `MatchSetupCubit`.
///
/// Пока поле показывает баннер, итог раунда, паузу или конец партии (`FieldState.isBusy`), следующие состояния партии
/// ждут в очереди и выходят на экран по одному, когда показ закончился: бот и сетевой соперник могут ходить быстрее,
/// чем идут анимации, но игрок видит ходы по порядку. Тот же порядок будет у анимаций карт (ADR 0013).
class MatchScreen extends StatefulWidget {
  /// Создаёт экран; [onExit] уводит из партии в меню, [onEditDeck] открывает колоду в конструкторе, [confirmPass]
  /// включает диалог подтверждения паса, [animationScale] задаёт скорость анимаций карт, [onSettings] открывает настройки
  /// из меню паузы.
  const MatchScreen({
    super.key,
    required this.onExit,
    required this.onEditDeck,
    this.confirmPass = false,
    this.animationScale = 1,
    this.onSettings,
    this.overlay,
  });

  /// Выход из партии.
  final VoidCallback onExit;

  /// Игрок хочет изменить колоду с данным идентификатором.
  final ValueChanged<String> onEditDeck;

  /// Спрашивать подтверждение паса диалогом; иначе пас нужно держать 1 с.
  final bool confirmPass;

  /// Доля обычных длительностей анимаций карт: 1 или `StageTokens.fastFactor` для быстрой скорости (ADR 0017).
  final double animationScale;

  /// Открыть настройки поверх партии; `null` — в меню паузы кнопка «Настройки» недоступна.
  final VoidCallback? onSettings;

  /// Слой поверх поля, пока партия идёт (связь в сетевой партии, ADR 0019); `null` — слоя нет.
  final Widget? overlay;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  /// Состояния партии, которые ждут, пока поле закончит показ.
  final Queue<MatchScreenState> _waiting = Queue();

  /// Что сейчас на экране.
  late MatchScreenState _shown = context.read<MatchBloc>().state;

  bool _releasing = false;

  /// Системное «назад» уводит из партии только до её начала и после конца. Посреди партии оно не выходит молча:
  /// на поле его перехватывает пауза (`FieldView`), на остальных экранах старта выхода нет, чтобы не потерять партию.
  bool _canLeave(MatchScreenState state) => switch (state) {
    MatchIdle() || MatchStarting() || MatchStartFailed() || MatchFinished() || MatchCrashed() => true,
    MatchIntro() || MatchToss() || MatchHandover() || MatchInProgress() => false,
  };

  /// Идёт партия: поле, пересдача или выбор первого игрока; на знакомстве, жребии, передаче и итоге слоя нет.
  bool get _fieldIsShown => switch (_shown) {
    MatchInProgress(:final view) => view.phase != MatchPhase.finished,
    _ => false,
  };

  /// Поле на экране и показывает что-то: следующее состояние партии подождёт. Остальные экраны очередь не держат.
  bool get _fieldIsBusy =>
      switch (_shown) {
        MatchInProgress(:final view) => view.phase == MatchPhase.playing || view.phase == MatchPhase.finished,
        _ => false,
      } &&
      context.read<FieldCubit>().state.isBusy;

  void _onMatchState(MatchScreenState state) {
    if (state is MatchCrashed || (state is MatchInProgress && state.events.any(_isResignation))) {
      // Партия сломалась или кто-то сдался: ждать анимаций незачем, а то, что в очереди, уже не покажешь.
      _waiting.clear();
      _show(state);
    } else if (state is MatchFinished && state.events.any(_isResignation)) {
      // Итог сдачи ждёт только плашку исхода, которая идёт перед ним, остальное в очереди устарело.
      _waiting.clear();
      if (_fieldIsBusy) {
        _waiting.add(state);
      } else {
        _show(state);
      }
    } else if (_waiting.isEmpty && !_fieldIsBusy) {
      _show(state);
    } else {
      _waiting.add(state);
    }
  }

  static bool _isResignation(GameEvent event) =>
      event is MatchEnded && event.outcome.reason == MatchEndReason.resignation;

  void _release() {
    if (_releasing) return;
    _releasing = true;
    try {
      while (_waiting.isNotEmpty && mounted && !_fieldIsBusy) {
        _show(_waiting.removeFirst());
      }
    } finally {
      _releasing = false;
    }
  }

  /// Сдача не ждёт очереди: сначала на экран выходит то, что партия показывает сейчас, потом уходит намерение. Иначе
  /// оно улетело бы в состояние, которое уже не принимает намерений (передача телефона, конец партии).
  void _submit(Intent intent) {
    final bloc = context.read<MatchBloc>();
    if (intent is Resign && _waiting.isNotEmpty) {
      _waiting.clear();
      _show(bloc.state);
    }
    bloc.add(MatchIntentSubmitted(intent));
  }

  /// Скорость из настроек и «Уменьшить движение» из системы: длительности анимаций считаются при сборке сценария.
  StageStyle get _stageStyle => StageStyle(
    scale: widget.animationScale,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
  );

  void _show(MatchScreenState state) {
    setState(() => _shown = state);
    context.read<FieldCubit>().onMatchState(state, style: _stageStyle);
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<MatchBloc, MatchScreenState>(listener: (context, state) => _onMatchState(state)),
      BlocListener<FieldCubit, FieldState>(
        listenWhen: (previous, current) => previous.isBusy && !current.isBusy,
        listener: (context, state) => _release(),
      ),
    ],
    child: Scaffold(
      backgroundColor: GwentColors.bg,
      body: PopScope(
        canPop: _canLeave(_shown),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _stage(context, _shown),
            if (_fieldIsShown) ?widget.overlay,
          ],
        ),
      ),
    ),
  );

  Widget _stage(BuildContext context, MatchScreenState state) {
    final l10n = context.l10n;
    final bloc = context.read<MatchBloc>();
    final submit = _submit;
    return switch (state) {
      MatchIdle() => MatchSetupStage(
        onStart: (request) => bloc.add(MatchStartRequested(request)),
        onEditDeck: widget.onEditDeck,
        onExit: widget.onExit,
      ),
      MatchStarting() => const SafeArea(child: Center(child: GameLoader())),
      MatchStartFailed() => SafeArea(
        child: MatchPanel(
          title: l10n.matchStartFailed,
          actions: [(label: l10n.matchExit, onPressed: widget.onExit, primary: true)],
        ),
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
        _ => FieldView(
          view: view,
          content: content,
          roster: roster,
          onIntent: submit,
          confirmPass: widget.confirmPass,
          onSettings: widget.onSettings,
        ),
      },
      MatchFinished(:final view, :final roster, :final canRematch) => MatchResultView(
        view: view,
        roster: roster,
        onExit: widget.onExit,
        onRematch: canRematch ? () => bloc.add(const MatchRematchRequested()) : null,
        // Поле, на котором кончилась партия, видно за листом и по кнопке «Показать поле» (макет 13).
        field: FieldView(view: view, content: roster.content, roster: roster, onIntent: (_) {}, readOnly: true),
      ),
      MatchCrashed() => SafeArea(
        child: MatchPanel(
          title: l10n.matchCrashed,
          actions: [(label: l10n.matchExit, onPressed: widget.onExit, primary: true)],
        ),
      ),
    };
  }
}
