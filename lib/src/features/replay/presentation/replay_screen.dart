import 'dart:async';

import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchMode;
import 'package:gwent/src/features/replay/presentation/replay_controls.dart';
import 'package:gwent/src/features/replay/presentation/replay_cubit.dart';
import 'package:gwent/src/features/replay/presentation/replay_state.dart';
import 'package:gwent/src/features/sound/application/play_sound.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;

/// Реплей партии: сыгранная партия на том же поле, что и в игре, с полосой управления под ним.
///
/// Поле только смотрят (`FieldView(readOnly: true)`): ходов, паса и паузы нет, карты и сброс можно рассматривать.
/// Партия идёт теми же анимациями, что в игре, потому что `FieldCubit` получает те же события и проекции; какой шаг
/// на поле, говорит `ReplayCubit`. Если реплей не открывается, экран говорит почему (ADR 0029).
class ReplayScreen extends StatelessWidget {
  /// Создаёт экран; [onExit] закрывает реплей, [animationScale] задаёт скорость анимаций карт из настроек, [sound]
  /// играет звуки партии (без него реплей идёт без звука).
  const ReplayScreen({super.key, required this.onExit, this.animationScale = 1, this.sound});

  /// Выход из реплея.
  final VoidCallback onExit;

  /// Доля обычных длительностей анимаций карт из настроек: 1 или `StageTokens.fastFactor`.
  final double animationScale;

  /// Звуки партии; `null` — без звука.
  final PlaySound? sound;

  @override
  Widget build(BuildContext context) => BlocBuilder<ReplayCubit, ReplayState>(
    builder: (context, state) => switch (state) {
      ReplayLoading() => _Plain(onExit: onExit, child: const GameLoader()),
      ReplayFailed(:final failure) => _Plain(
        onExit: onExit,
        child: _Message(switch (failure) {
          ReplayFailure.missing => context.l10n.replayMissing,
          ReplayFailure.contentUnavailable => context.l10n.replayContentUnavailable,
          ReplayFailure.contentChanged => context.l10n.replayContentChanged,
          ReplayFailure.corrupted => context.l10n.replayCorrupted,
        }),
      ),
      ReplayShowing() => _Stage(onExit: onExit, animationScale: animationScale, sound: sound),
    },
  );
}

/// Экран без поля: заголовок и то, что сказать (загрузка или причина, почему реплея нет).
class _Plain extends StatelessWidget {
  const _Plain({required this.onExit, required this.child});

  final VoidCallback onExit;
  final Widget child;

  @override
  Widget build(BuildContext context) => ScreenBackdrop(
    child: Column(
      children: [
        ScreenHeader(title: context.l10n.replayTitle, titleSize: 34, onBack: onExit),
        Expanded(child: child),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: GwentText.alegreya, fontSize: 17, color: GwentColors.textSecondary),
      ),
    ),
  );
}

/// Поле реплея и полоса управления. Держит `FieldCubit` и передаёт ему шаги, которые называет `ReplayCubit`.
class _Stage extends StatefulWidget {
  const _Stage({required this.onExit, required this.animationScale, required this.sound});

  final VoidCallback onExit;
  final double animationScale;
  final PlaySound? sound;

  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> {
  late final FieldCubit _field = FieldCubit(sound: widget.sound);
  late final ReplayCubit _replay = context.read<ReplayCubit>();
  MatchRoster? _roster;
  int _shownRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Первый шаг уже выбран, когда экран с полем появляется: слушатель состояния его не увидит. Стиль берёт
    // `MediaQuery`, поэтому показ начинается здесь, а не в `initState`.
    _show(_replay.state as ReplayShowing);
  }

  @override
  void dispose() {
    unawaited(_field.close());
    super.dispose();
  }

  /// Состав партии: имена закреплены за местами, а не за тем, чьими глазами смотрят (ADR 0029).
  MatchRoster _rosterOf(ReplayShowing state) => _roster ??= () {
    final record = state.data.record;
    final timeline = state.data.timeline;
    final views = timeline.frames.first.views;
    final hotSeat = record.mode == MatchMode.hotSeat;
    MatchPlayer player(Seat seat) {
      final side = views[seat]!.me;
      return MatchPlayer(seat: seat, faction: side.faction, leader: side.leader);
    }

    return MatchRoster(
      mode: record.mode,
      content: state.data.content,
      localSeats: hotSeat ? Seat.values.toSet() : {timeline.perspective},
      opponentName: record.opponentName,
      players: {for (final seat in Seat.values) seat: player(seat)},
    );
  }();

  StageStyle get _style =>
      StageStyle(scale: widget.animationScale * _speedScale, reduceMotion: MediaQuery.disableAnimationsOf(context));

  double get _speedScale => (_replay.state as ReplayShowing).speed.animationScale;

  void _show(ReplayShowing state) {
    if (state.revision == _shownRevision) return;
    _shownRevision = state.revision;
    if (state.reset) _field.reset();
    final step = state.step;
    _field.onMatchState(
      MatchInProgress(
        view: step.view,
        content: state.data.content,
        roster: _rosterOf(state),
        events: state.animate ? step.events : const [],
        closing: state.animate ? step.closing : null,
      ),
      style: _style,
    );
    _replay.fieldReported(busy: _field.state.isBusy);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider.value(
      value: _field,
      child: MultiBlocListener(
        listeners: [
          BlocListener<ReplayCubit, ReplayState>(
            listener: (context, state) {
              if (state is ReplayShowing) _show(state);
            },
          ),
          BlocListener<FieldCubit, FieldState>(
            listenWhen: (previous, current) => previous.isBusy != current.isBusy,
            listener: (context, state) => _replay.fieldReported(busy: state.isBusy),
          ),
        ],
        child: Scaffold(
          backgroundColor: GwentColors.bg,
          body: BlocBuilder<ReplayCubit, ReplayState>(
            builder: (context, state) {
              if (state is! ReplayShowing) return const SizedBox.shrink();
              final roster = _rosterOf(state);
              final seats = state.data.timeline.seats;
              return Column(
                children: [
                  Expanded(
                    // Нижнюю безопасную зону занимает полоса управления, поле её не повторяет.
                    child: MediaQuery.removePadding(
                      context: context,
                      removeBottom: true,
                      child: FieldView(
                        view: state.step.view,
                        content: state.data.content,
                        roster: roster,
                        onIntent: (_) {},
                        readOnly: true,
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: BlocBuilder<FieldCubit, FieldState>(
                      builder: (context, field) => ReplayControls(
                        state: state,
                        seatName: (seat) => roster.name(seat, l10n),
                        canStepForward: !field.isBusy,
                        onClose: widget.onExit,
                        onTogglePlay: _replay.togglePlay,
                        onPrevious: _replay.previous,
                        onNext: _replay.next,
                        onPreviousRound: _replay.previousRound,
                        onNextRound: _replay.nextRound,
                        onSpeed: () => _replay.setSpeed(state.speed.next),
                        onSeat: seats.length < 2
                            ? null
                            : () => _replay.setSeat(seats.firstWhere((seat) => seat != state.seat)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
