import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/features/haptics/application/play_haptic.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_lesson.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_screen.dart';
import 'package:gwent/src/features/match/presentation/match_stages.dart';
import 'package:gwent/src/features/sound/application/play_sound.dart';
import 'package:gwent/src/features/tutorial/application/mark_first_match_passed.dart';
import 'package:gwent/src/features/tutorial/presentation/first_match_cubit.dart';
import 'package:gwent/src/features/tutorial/presentation/first_match_state.dart';
import 'package:gwent/src/features/tutorial/presentation/tutorial_cubit.dart';
import 'package:gwent/src/features/tutorial/presentation/tutorial_done_sheet.dart';
import 'package:gwent/src/features/tutorial/presentation/tutorial_layer.dart';

/// Экран «Первой партии» (ADR 0034): партия по сценарию с подсказками и лист «Первая партия пройдена».
///
/// Партию показывает обычный `MatchScreen`, к которому подключён урок (`FieldLesson`): слой подсказок поверх поля,
/// «Начать заново» и «В меню» в паузе, лист завершения вместо итога матча. Держатели партии создаются заново с каждой
/// попыткой.
class FirstMatchScreen extends StatelessWidget {
  /// Создаёт экран; [onExit] ведёт в меню, [onPlayBot] — к партии против бота, [onSettings] открывает настройки.
  const FirstMatchScreen({
    super.key,
    required this.startMatch,
    required this.recordFinishedMatch,
    required this.markPassed,
    required this.onExit,
    required this.onPlayBot,
    this.onSettings,
    this.animationScale = 1,
    this.sound,
    this.haptic,
  });

  /// Сценарий начала партии: держателю партии он нужен для устройства, сама партия приходит готовой.
  final StartMatch startMatch;

  /// Сценарий записи партии в историю: «Первая партия» в историю не пишется, но держатель требует его.
  final RecordFinishedMatch recordFinishedMatch;

  /// Запоминает, что игрок прошёл обучение.
  final MarkFirstMatchPassed markPassed;

  /// Выход в меню.
  final VoidCallback onExit;

  /// «Играть против бота» на листе завершения.
  final VoidCallback onPlayBot;

  /// Открыть настройки из паузы; `null` — кнопка недоступна.
  final VoidCallback? onSettings;

  /// Доля обычных длительностей анимаций карт.
  final double animationScale;

  /// Звуки партии.
  final PlaySound? sound;

  /// Вибрация партии.
  final PlayHaptic? haptic;

  @override
  Widget build(BuildContext context) => BlocBuilder<FirstMatchCubit, FirstMatchState>(
    builder: (context, state) => switch (state) {
      FirstMatchLoading() => const Scaffold(
        backgroundColor: GwentColors.bg,
        body: SafeArea(child: Center(child: GameLoader())),
      ),
      FirstMatchFailed() => Scaffold(
        backgroundColor: GwentColors.bg,
        body: SafeArea(
          child: MatchPanel(
            title: context.l10n.tutorialStartFailed,
            actions: [(label: context.l10n.matchExit, onPressed: onExit, primary: true)],
          ),
        ),
      ),
      FirstMatchPlaying(:final session, :final director, :final attempt) => MultiBlocProvider(
        key: ValueKey(attempt),
        providers: [
          BlocProvider(
            create: (_) =>
                MatchBloc(startMatch, recordFinishedMatch, awaitingSession: true)..add(MatchSessionOpened(session)),
          ),
          BlocProvider(
            create: (_) => FieldCubit(sound: sound, haptic: haptic),
          ),
          BlocProvider(create: (_) => TutorialCubit(director, markPassed: markPassed)),
        ],
        child: MatchScreen(
          onExit: onExit,
          onEditDeck: (_) {},
          onSettings: onSettings,
          hints: true,
          animationScale: animationScale,
          lesson: FieldLesson(
            layerBuilder: (context, layout) => TutorialLayer(layout: layout, onSkip: onExit),
            finishedBuilder: (context, finished) => Stack(
              fit: StackFit.expand,
              children: [
                FieldView(
                  view: finished.view,
                  content: finished.roster.content,
                  roster: finished.roster,
                  onIntent: (_) {},
                  readOnly: true,
                ),
                TutorialDoneSheet(
                  onPlay: onPlayBot,
                  onAgain: context.read<FirstMatchCubit>().restart,
                  onMenu: onExit,
                ),
              ],
            ),
            onRestart: context.read<FirstMatchCubit>().restart,
            onExit: onExit,
          ),
        ),
      ),
    },
  );
}
