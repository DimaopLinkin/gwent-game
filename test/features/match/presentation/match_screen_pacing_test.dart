import 'dart:async';

import 'package:flutter/material.dart' hide Intent, Row;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/app/theme/app_theme.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match/presentation/field/hand_view.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_screen.dart';
import 'package:gwent/src/features/match/presentation/overlays/match_result_view.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' as history;
import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Deck;

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/match_fixtures.dart';
import 'field/field_fixtures.dart';

/// Стол, обновления которого присылает тест через `MatchTableUpdated`.
final class _FakeTable implements MatchTable {
  final StreamController<TableUpdate> _updates = StreamController();

  @override
  Set<Seat> get localSeats => const {Seat.one};

  @override
  Stream<TableUpdate> get updates => _updates.stream;

  @override
  void submit(Seat seat, Intent intent) {}

  @override
  Future<void> close() => _updates.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late TestCards cards;
  late MatchBloc bloc;
  late FieldCubit field;

  setUpAll(() async {
    content = await loadBaseContent();
    await loadDesignFonts();
  });

  setUp(() {
    cards = TestCards(content);
    bloc = MatchBloc(
      StartMatch(
        LoadGameContent(AssetContentSource.basePack(rootBundle)),
        InMemoryDeckRepository(),
        FixedSeedGenerator(3),
        createBot: GreedyBot.new,
        botThinkTime: Duration.zero,
      ),
      RecordFinishedMatch(
        RecordMatch(InMemoryMatchHistoryRepository(), FakeClock(DateTime.utc(2026, 10, 18)), SequentialIdGenerator()),
      ),
    );
    addTearDown(bloc.close);
  });

  PlayerView withHand(int size, {Seat? turn = Seat.one, MatchPhase phase = MatchPhase.playing}) => viewOf(
    cards,
    turn: turn,
    phase: phase,
    outcome: phase == MatchPhase.finished
        ? const MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals)
        : null,
    me: sideOf(cards, Seat.one, hand: [for (var i = 0; i < size; i++) cards.unit(Row.melee)]),
  );

  /// Стол присылает проекцию игроку: она доходит до экрана через настоящий `MatchBloc`.
  Future<void> push(WidgetTester tester, PlayerView view, [List<GameEvent> events = const []]) async {
    bloc.add(MatchTableUpdated(ViewsChanged({Seat.one: view}, {Seat.one: events})));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }

  Future<void> endBanners(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Экран партии над столом, партия дошла до поля с [view].
  Future<void> pumpField(
    WidgetTester tester,
    PlayerView view, {
    Duration finishHold = const Duration(seconds: 2),
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final table = _FakeTable();
    addTearDown(table.close);
    bloc.add(
      MatchSessionOpened(
        MatchSession(
          mode: history.MatchMode.ai,
          table: table,
          content: content,
          factionIds: const {Seat.one: 'skellige', Seat.two: 'monsters'},
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await push(tester, view);
    bloc.add(const MatchIntroFinished());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    field = FieldCubit(finishHold: finishHold);
    addTearDown(field.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<MatchBloc>.value(value: bloc),
          BlocProvider<FieldCubit>.value(value: field),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: MatchScreen(onExit: () {}, onEditDeck: (_) {}),
        ),
      ),
    );
    await endBanners(tester);
  }

  Finder handCards() => find.descendant(of: find.byType(HandView), matching: find.byType(GwentCard));

  group('безопасные зоны', () {
    testWidgets('экран партии не ужимает экраны безопасной областью: фон идёт на весь экран', (tester) async {
      await pumpField(tester, withHand(1));
      tester.view
        ..padding = const FakeViewPadding(top: 59, bottom: 34)
        ..viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.reset);
      await tester.pump();
      expect(tester.getRect(find.byType(FieldView)), const Rect.fromLTWH(0, 0, 390, 844));

      await push(tester, withHand(0, turn: null, phase: MatchPhase.finished), const [
        MatchEnded(MatchOutcome(winner: Seat.two, reason: MatchEndReason.resignation)),
      ]);
      expect(tester.getRect(find.byType(MatchResultView)), const Rect.fromLTWH(0, 0, 390, 844));
    });
  });

  group('очередь показа партии', () {
    testWidgets('ход соперника, пришедший во время баннера, показывается после него', (tester) async {
      await pumpField(tester, withHand(3));
      expect(handCards(), findsNWidgets(3));

      await push(tester, withHand(3, turn: Seat.two), const [TurnStarted(Seat.two)]);
      await tester.pump(const Duration(milliseconds: 100));
      expect(field.state.isBusy, isTrue, reason: 'идёт баннер «Ход соперника»');

      // Бот сыграл карту, пока баннер ещё на экране: игрок её пока не видит.
      await push(tester, withHand(2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(handCards(), findsNWidgets(3), reason: 'ход бота ждёт конца баннера');

      await endBanners(tester);
      expect(handCards(), findsNWidgets(2), reason: 'после баннера ход бота на экране');
    });

    testWidgets('несколько ходов подряд выходят по одному, в порядке прихода', (tester) async {
      await pumpField(tester, withHand(4));
      await push(tester, withHand(3), const [TurnStarted(Seat.one)]);
      await push(tester, withHand(2, turn: Seat.two), const [TurnStarted(Seat.two)]);
      await tester.pump(const Duration(milliseconds: 200));
      expect(handCards(), findsNWidgets(3), reason: 'на экране первый из пришедших, остальные ждут');

      await endBanners(tester);
      // Второй ход вышел после первого баннера и принёс свой баннер: ещё один срок ожидания.
      await endBanners(tester);
      expect(handCards(), findsNWidgets(2));
    });

    testWidgets('итог матча ждёт, пока поле держит последний ход и счёт', (tester) async {
      await pumpField(tester, withHand(1));

      await push(tester, withHand(0, turn: null, phase: MatchPhase.finished), const [
        MatchEnded(MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals)),
      ]);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(FieldView), findsOneWidget);
      expect(find.text('Партия окончена'), findsOneWidget);
      expect(find.byType(MatchResultView), findsNothing);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(MatchResultView), findsNothing, reason: 'поле держит конец партии 2 секунды');

      await tester.pump(const Duration(milliseconds: 800));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
      expect(find.byType(MatchResultView), findsOneWidget);
      expect(find.byType(FieldView), findsNothing);
    });

    testWidgets('сдача не ждёт анимаций: итог матча открывается сразу', (tester) async {
      await pumpField(tester, withHand(1));
      await push(tester, withHand(1, turn: Seat.two), const [TurnStarted(Seat.two)]);
      expect(field.state.isBusy, isTrue);

      await push(tester, withHand(1, turn: null, phase: MatchPhase.finished), const [
        MatchEnded(MatchOutcome(winner: Seat.two, reason: MatchEndReason.resignation)),
      ]);
      expect(find.byType(MatchResultView), findsOneWidget);
    });

    testWidgets('пока идёт пауза, следующее состояние партии ждёт; после «Продолжить» выходит', (tester) async {
      await pumpField(tester, withHand(3));
      field.openPause();
      await tester.pump();

      await push(tester, withHand(2));
      expect(handCards(), findsNWidgets(3), reason: 'ход бота не показывается под паузой');
      field.closePause();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(handCards(), findsNWidgets(2));
    });
  });
}
