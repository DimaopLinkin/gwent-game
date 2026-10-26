import 'package:flutter/material.dart' hide Intent, Row;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/confirm_dialog.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_screen.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match/presentation/overlays/round_summary_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_intro_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_toss_view.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/tutorial/application/mark_first_match_passed.dart';
import 'package:gwent/src/features/tutorial/application/start_first_match.dart';
import 'package:gwent/src/features/tutorial/domain/scenario_beat.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_move.dart';
import 'package:gwent/src/features/tutorial/presentation/first_match_cubit.dart';
import 'package:gwent/src/features/tutorial/presentation/first_match_screen.dart';
import 'package:gwent/src/features/tutorial/presentation/first_match_state.dart';
import 'package:gwent/src/features/tutorial/presentation/hint_scrim.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Deck, Row;

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/screen_guards.dart';

/// «Первая партия» целиком на настоящем пакете карт, движке и экране партии: показы, ходы игрока, ход бота, конец
/// раундов и лист завершения. Время партии настоящее (стол и бот живут на потоках), поэтому тест ждёт его кусками.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  late InMemorySettingsRepository settings;
  late InMemoryMatchHistoryRepository history;
  late FirstMatchCubit cubit;
  late int exits;
  late int botPlays;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    await loadDesignFonts();
  });

  Future<void> pumpScreen(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    exits = 0;
    botPlays = 0;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    settings = InMemorySettingsRepository();
    history = InMemoryMatchHistoryRepository();
    final content = LoadGameContent(AssetContentSource.basePack(rootBundle));
    cubit = FirstMatchCubit(
      StartFirstMatch(content, botThinkTime: Duration.zero),
      playerDeckName: 'Первая партия',
      opponentDeckName: 'Скеллиге',
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: localizedScreen(
          FirstMatchScreen(
            startMatch: StartMatch(content, InMemoryDeckRepository(), FixedSeedGenerator(3)),
            recordFinishedMatch: RecordFinishedMatch(
              RecordMatch(history, FakeClock(DateTime.utc(2026, 10, 26)), SequentialIdGenerator()),
            ),
            markPassed: MarkFirstMatchPassed(settings),
            onExit: () => exits++,
            onPlayBot: () => botPlays++,
          ),
        ),
      ),
    );
  }

  /// Ждёт настоящее время и крутит кадры, пока [done] не выполнится; нажимает то, что закрывает показ сам.
  Future<void> pumpUntil(WidgetTester tester, bool Function() done, {String? reason}) async {
    for (var i = 0; i < 400; i++) {
      if (done()) return;
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(MatchIntroView).evaluate().isNotEmpty) await tester.tap(find.byType(MatchIntroView));
      if (find.byType(MatchTossView).evaluate().isNotEmpty) await tester.tap(find.byType(MatchTossView));
      if (find.byType(RoundSummaryView).evaluate().isNotEmpty) await tester.tap(find.byType(RoundSummaryView));
    }
    fail('не дождались: ${reason ?? 'условия'}');
  }

  Future<void> untilStep(WidgetTester tester, int step) => pumpUntil(
    tester,
    () => find.text(l10n.tutorialStepCounter(step, 15)).evaluate().isNotEmpty,
    reason: 'шага $step',
  );

  List<HintWindow> hintWindows(WidgetTester tester) =>
      tester.widget<HintScrim>(find.byType(HintScrim)).windows.where((window) => window.framed).toList();

  /// Делает ход игрока пальцем: нажимает подсвеченные окна слоя, как это делает человек.
  Future<void> playByTapping(WidgetTester tester, PlayerBeat beat) async {
    // Окна измеряются кадром после появления слоя, а поле может ещё показывать ход соперника: слой должен простоять.
    bool ready() =>
        find.byType(HintScrim).evaluate().isNotEmpty && hintWindows(tester).any((window) => window.touch != null);
    await pumpUntil(tester, ready, reason: 'окон для нажатия');
    await tester.pump(const Duration(milliseconds: 700));
    await pumpUntil(tester, ready, reason: 'окон для нажатия после показа');
    switch (beat.move) {
      case PlayMove():
        final card = hintWindows(tester).first;
        expect(card.touch, isNotNull, reason: 'у карты есть место для нажатия');
        await tester.tapAt(card.touch!.center);
        await tester.pump(const Duration(milliseconds: 400));
        // Карта с единственным местом (погода) играется сразу, остальным нужно ещё место.
        if (find.byType(HintScrim).evaluate().isEmpty) return;
        final destination = hintWindows(tester)[1];
        await tester.tapAt(destination.touch!.center);
      case PassMove():
        final pass = hintWindows(tester).first;
        final gesture = await tester.startGesture(pass.touch!.center);
        // Заливка идёт от первого кадра после нажатия, а не от самого нажатия.
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 1200));
        await gesture.up();
      case LeaderMove():
        final leader = hintWindows(tester).first;
        await tester.tapAt(leader.touch!.center);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text(l10n.fieldLeaderUse));
    }
  }

  FirstMatchPlaying playing() => cubit.state as FirstMatchPlaying;

  testWidgets('первый шаг: карточка «Шаг 1 из 15», «Дальше» ведёт к шагу 2, нажатие мимо напоминает', (tester) async {
    await pumpScreen(tester);
    await untilStep(tester, 1);
    expect(find.text(l10n.tutorialStepGoalTitle), findsOneWidget);
    expect(find.text(l10n.tutorialNowNext), findsNothing);
    expectNoFallbackTextStyle(tester);

    // Затемнение ловит нажатие по полю и напоминает, что нужно «Дальше».
    await tester.tapAt(const Offset(195, 400));
    await tester.pump();
    expect(find.text(l10n.tutorialNowNext), findsOneWidget);
    expect(playing().director.index, 0);

    await tester.tap(find.text(l10n.tutorialNext));
    await untilStep(tester, 2);
    expect(find.text(l10n.tutorialStepHandAndDeckTitle), findsOneWidget);
    expect(find.text(l10n.tutorialNowNext), findsNothing, reason: 'напоминание уходит со сменой шага');
  });

  testWidgets('ход игрока: окна пропускают нажатия к полю, остальное затемнение ловит и напоминает', (tester) async {
    await pumpScreen(tester);
    for (var step = 1; step <= 3; step++) {
      await untilStep(tester, step);
      await tester.tap(find.text(l10n.tutorialNext));
    }
    await untilStep(tester, 4);
    expect(find.text(l10n.tutorialStepFirstCardTitle), findsOneWidget);
    expect(find.text(l10n.tutorialWaiting), findsOneWidget);
    final windows = tester.widget<HintScrim>(find.byType(HintScrim)).windows;
    // Карта в руке и ближний ряд игрока; пауза пропускает нажатия без рамки.
    final card = windows.first;
    final row = windows[1];
    expect(card.touch, isNotNull);
    expect(row.touch, isNotNull);

    // Мимо окон: затемнение ловит нажатие, карточка напоминает.
    await tester.tapAt(const Offset(5, 300));
    await tester.pump();
    expect(find.text(l10n.tutorialNowCard), findsOneWidget);
    expect(playing().director.index, 3);

    // Подсвеченная карта выбирается: нажатие дошло до поля.
    await tester.tapAt(card.touch!.center);
    await tester.pump(const Duration(milliseconds: 300));
    final field = tester.element(find.byType(HintScrim)).read<FieldCubit>();
    expect(field.state.selected, isNotNull);
    await tester.tapAt(const Offset(5, 300));
    await tester.pump();
    expect(find.text(l10n.tutorialNowTarget), findsOneWidget);

    // Подсвеченный ряд принимает карту: сценарий идёт дальше.
    await tester.tapAt(row.touch!.center);
    await pumpUntil(tester, () => playing().director.index > 3, reason: 'хода игрока');
  });

  testWidgets('карточку можно свернуть в «?» и вернуть', (tester) async {
    await pumpScreen(tester);
    await untilStep(tester, 1);

    await tester.tap(find.bySemanticsLabel(l10n.tutorialCollapse));
    await tester.pump();
    expect(find.text(l10n.tutorialStepGoalTitle), findsNothing);
    expect(find.bySemanticsLabel(l10n.tutorialExpand), findsOneWidget);
    expect(find.byType(HintScrim), findsOneWidget, reason: 'затемнение остаётся');

    await tester.tap(find.bySemanticsLabel(l10n.tutorialExpand));
    await tester.pump();
    expect(find.text(l10n.tutorialStepGoalTitle), findsOneWidget);
  });

  testWidgets('«Пропустить» спрашивает подтверждение и уводит из обучения только после него', (tester) async {
    await pumpScreen(tester);
    await untilStep(tester, 1);

    await tester.tap(find.text(l10n.tutorialSkip));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.tutorialSkipTitle), findsOneWidget);
    await tester.tap(find.text(l10n.dialogCancel));
    await tester.pump(const Duration(milliseconds: 300));
    expect(exits, 0);

    await tester.tap(find.text(l10n.tutorialSkip));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.descendant(of: find.byType(ConfirmDialog), matching: find.text(l10n.tutorialSkipConfirm)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(exits, 1);
    expect(settings.saved.firstMatchPassed, isFalse, reason: 'пропуск обучением не считается');
  });

  testWidgets('пауза в обучении: «Начать заново» вместо «Сдаться», заново идёт с первого шага', (tester) async {
    await pumpScreen(tester);
    await untilStep(tester, 1);
    await tester.tap(find.text(l10n.tutorialNext));
    await untilStep(tester, 2);

    await tester.tap(find.bySemanticsLabel(l10n.pauseButtonSemantics));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.pauseRestart), findsOneWidget);
    expect(find.text(l10n.pauseToMenu), findsOneWidget);
    expect(find.text(l10n.pauseSurrender), findsNothing, reason: 'партию в обучении не сдают');

    await tester.tap(find.text(l10n.pauseRestart));
    await pumpUntil(tester, () => find.text(l10n.tutorialStepCounter(1, 15)).evaluate().isNotEmpty, reason: 'шага 1');
    expect(playing().attempt, 1);
    expect(playing().director.index, 0);
  });

  testWidgets('на узком экране карточка и кнопки целы, ничего не переполняется', (tester) async {
    await pumpScreen(tester, size: const Size(320, 568));
    await untilStep(tester, 1);
    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.text(l10n.tutorialNext));
    expect(card.left, greaterThanOrEqualTo(0));
    expect(card.right, lessThanOrEqualTo(320));
    expect(card.bottom, lessThanOrEqualTo(568));
    await tester.tap(find.text(l10n.tutorialNext));
    await untilStep(tester, 2);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(390, 844), Size(375, 667)]) {
    testWidgets(
      'вся партия ${size.width.toInt()}×${size.height.toInt()}: 15 шагов, ходы пальцем, победа 2:0, лист, флаг',
      (
        tester,
      ) async {
        await pumpScreen(tester, size: size);
        await untilStep(tester, 1);
        final started = playing();
        final director = started.director;
        // Проекцию игрока читает держатель партии: стол слушает он один.
        PlayerView view() => switch (tester.element(find.byType(MatchScreen)).read<MatchBloc>().state) {
          MatchInProgress(:final view) || MatchFinished(:final view) => view,
          final other => fail('партия не на поле: $other'),
        };
        final steps = <int>{};

        var guard = 0;
        while (!director.isCompleted && guard++ < 60) {
          final index = director.index;
          switch (director.current!) {
            case ShowBeat(:final step):
              steps.add(step.number);
              await pumpUntil(
                tester,
                () => find.text(l10n.tutorialNext).evaluate().isNotEmpty,
                reason: 'кнопки «Дальше»',
              );
              await tester.tap(find.text(l10n.tutorialNext));
            case final PlayerBeat beat:
              final step = beat.step;
              if (step != null) steps.add(step.number);
              // Слой появляется, когда поле закончило показ: тогда ход можно делать.
              await pumpUntil(tester, () => find.byType(HintScrim).evaluate().isNotEmpty, reason: 'хода игрока');
              await playByTapping(tester, beat);
            case BotBeat():
              break;
          }
          await pumpUntil(tester, () => director.index > index, reason: 'следующего звена после $index');
        }
        expect(director.isCompleted, isTrue);
        expect(steps, {for (var step = 1; step <= 15; step++) step});

        await pumpUntil(
          tester,
          () => find.text(l10n.tutorialDoneTitle).evaluate().isNotEmpty,
          reason: 'листа завершения',
        );
        expect(find.text(l10n.tutorialDonePlay), findsOneWidget);
        expect(find.text(l10n.tutorialDoneAgain), findsOneWidget);
        expect(find.text(l10n.tutorialDoneMenu), findsOneWidget);
        expect(view().outcome!.winner, Seat.one);
        expect(settings.saved.firstMatchPassed, isTrue);
        expect(history.records, isEmpty, reason: 'учебная партия в историю не попадает');
        expectNoFallbackTextStyle(tester);

        await tester.tap(find.text(l10n.tutorialDonePlay));
        expect(botPlays, 1);
        await tester.tap(find.text(l10n.tutorialDoneMenu));
        expect(exits, 1);

        await tester.tap(find.text(l10n.tutorialDoneAgain));
        await pumpUntil(
          tester,
          () => find.text(l10n.tutorialStepCounter(1, 15)).evaluate().isNotEmpty,
          reason: 'шага 1',
        );
        expect(playing().attempt, 1);
      },
    );
  }
}
