import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/pause_button.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent/src/features/replay/application/load_replay.dart';
import 'package:gwent/src/features/replay/presentation/replay_cubit.dart';
import 'package:gwent/src/features/replay/presentation/replay_screen.dart';
import 'package:gwent/src/features/replay/presentation/replay_state.dart';

import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/replay_fixtures.dart';
import '../../../support/screen_guards.dart';

/// История, у которой запись реплея не читается.
final class _CorruptedHistory implements MatchHistoryRepository {
  _CorruptedHistory(this._record);

  final MatchRecord _record;

  @override
  Stream<List<MatchRecord>> watchAll() => Stream.value([_record]);

  @override
  Future<MatchRecord?> findById(String id) async => _record;

  @override
  Future<void> add(MatchRecord record, {ReplayLog? replay}) async {}

  @override
  Future<ReplayLog?> findReplay(String recordId) async => throw const ReplayCorrupted('испорчено');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayedMatch match;
  late AppLocalizations l10n;

  setUpAll(() async {
    await loadDesignFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    match = await playRecordedMatch();
  });

  var exits = 0;
  setUp(() => exits = 0);

  Future<ReplayCubit> pumpReplay(
    WidgetTester tester, {
    String? recordId,
    LoadReplay? load,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = (await tester.runAsync(() async {
      final cubit = ReplayCubit(load ?? LoadReplay(match.history, match.loader), recordId ?? match.record.id);
      await cubit.stream.firstWhere((state) => state is! ReplayLoading);
      return cubit;
    }))!;
    addTearDown(cubit.close);
    await tester.pumpWidget(
      localizedScreen(
        BlocProvider.value(
          value: cubit,
          child: ReplayScreen(onExit: () => exits++),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expectNoFallbackTextStyle(tester);
    return cubit;
  }

  testWidgets('реплей показывает поле только для просмотра и полосу управления', (tester) async {
    final cubit = await pumpReplay(tester);

    expect(find.byType(FieldView), findsOneWidget);
    expect(tester.widget<FieldView>(find.byType(FieldView)).readOnly, isTrue);
    final state = cubit.state as ReplayShowing;
    expect(find.text(l10n.replayProgress(1, state.steps.length, state.step.round)), findsOneWidget);
    expect(find.byType(PauseButton), findsNothing, reason: 'в реплее нет паузы партии и сдачи');
    expect(tester.takeException(), isNull);
  });

  testWidgets('кнопки управления зовут держатель: пауза, шаги, скорость, зритель, закрытие', (tester) async {
    final handle = tester.ensureSemantics();
    final cubit = await pumpReplay(tester);
    ReplayShowing state() => cubit.state as ReplayShowing;

    await tester.tap(find.bySemanticsLabel(l10n.replayPause));
    await tester.pump();
    expect(state().playing, isFalse);
    expect(find.bySemanticsLabel(l10n.replayPlay), findsOneWidget);

    // Пока идут баннеры начала партии, поле занято, и шаг вперёд не принимается; дождёмся конца показа.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.bySemanticsLabel(l10n.replayStepForward));
    await tester.pump();
    expect(state().index, 1);
    expect(state().playing, isFalse);

    await tester.tap(find.bySemanticsLabel(l10n.replayStepBack));
    await tester.pump();
    expect(state().index, 0);
    expect(state().reset, isTrue);

    await tester.tap(find.bySemanticsLabel(l10n.replaySpeed('1')));
    await tester.pump();
    expect(state().speed, ReplaySpeed.fast);
    expect(find.bySemanticsLabel(l10n.replaySpeed('2')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^${l10n.replayWatchAs('')}')));
    await tester.pump();
    expect(state().seat.name, 'two');

    await tester.tap(find.bySemanticsLabel(l10n.replayClose));
    expect(exits, 1);
    handle.dispose();
  });

  testWidgets('реплей идёт сам и доходит до конца партии, где останавливается', (tester) async {
    final cubit = await pumpReplay(tester);
    cubit.setSpeed(ReplaySpeed.fastest);

    // Доиграть партию целиком: ходы выходят по мере того, как поле заканчивает показ.
    var pumps = 0;
    while (!(cubit.state as ReplayShowing).atEnd && pumps++ < 4000) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 5));

    final state = cubit.state as ReplayShowing;
    expect(state.atEnd, isTrue);
    expect(state.playing, isFalse);
    expect(state.step.view.outcome, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('на узком экране полоса управления и поле помещаются', (tester) async {
    await pumpReplay(tester, size: const Size(320, 568));

    expect(tester.takeException(), isNull);
  });

  testWidgets('нет такой партии: понятное сообщение и «назад»', (tester) async {
    await pumpReplay(tester, recordId: 'нет такой');

    expect(find.text(l10n.replayMissing), findsOneWidget);
    expectBackButtonAtEdge(tester);
  });

  testWidgets('повреждённая запись: реплей не открывается и говорит об этом', (tester) async {
    final load = LoadReplay(_CorruptedHistory(match.record), match.loader);
    await pumpReplay(tester, load: load);

    expect(find.text(l10n.replayCorrupted), findsOneWidget);
    expectBackButtonAtEdge(tester);
  });
}
