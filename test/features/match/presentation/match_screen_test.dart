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
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_screen.dart';
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_stages.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Deck;

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/match_fixtures.dart';
import 'field/field_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late InMemoryDeckRepository decks;
  late MatchBloc bloc;
  late int exits;

  setUpAll(() async {
    content = await loadBaseContent();
    await loadDesignFonts();
  });

  setUp(() {
    exits = 0;
    decks = InMemoryDeckRepository([
      realDeck(content, Faction.skellige, id: 'skellige'),
      realDeck(content, Faction.monsters, id: 'monsters'),
    ]);
    bloc = MatchBloc(
      StartMatch(
        LoadGameContent(AssetContentSource.basePack(rootBundle)),
        decks,
        FixedSeedGenerator(3),
        createBot: GreedyBot.new,
        botThinkTime: Duration.zero,
      ),
      RecordFinishedMatch(
        RecordMatch(InMemoryMatchHistoryRepository(), FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator()),
      ),
    );
    addTearDown(bloc.close);
  });

  Future<void> pumpScreen(WidgetTester tester, {bool preselect = true, Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final setup = MatchSetupCubit(WatchDecks(decks), preselect: preselect);
    addTearDown(setup.close);
    final field = FieldCubit();
    addTearDown(field.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<MatchBloc>.value(value: bloc),
          BlocProvider<MatchSetupCubit>.value(value: setup),
          BlocProvider<FieldCubit>.value(value: field),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: MatchScreen(onExit: () => exits++),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Партия идёт на настоящем столе с таймерами и потоками: ждём настоящее время, а не фальшивые часы.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> startVsBot(WidgetTester tester) async {
    await tester.tap(find.text('Начать партию'));
    await settle(tester);
  }

  testWidgets('выбор партии: режим, колоды выбраны сразу, кнопка «Начать партию» активна', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Новая партия'), findsOneWidget);
    expect(find.text('Против бота'), findsOneWidget);
    expect(find.text('Вдвоём на одном телефоне'), findsOneWidget);
    expect(find.text('Колода бота'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Начать партию')).onPressed, isNotNull);
  });

  testWidgets('без предвыбора колод партию начать нельзя, пока колоды не выбраны', (tester) async {
    await pumpScreen(tester, preselect: false);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Начать партию')).onPressed, isNull);
    await tester.tap(find.text('skellige').first);
    await tester.pump();
    await tester.tap(find.text('monsters').last);
    await tester.pump();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Начать партию')).onPressed, isNotNull);
  });

  testWidgets('режим на двоих меняет подпись второй колоды', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Вдвоём на одном телефоне'));
    await tester.pump();
    expect(find.text('Колода второго игрока'), findsOneWidget);
    expect(find.text('Колода бота'), findsNothing);
  });

  testWidgets('«В меню» на экране выбора уходит из партии', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('В меню'));
    expect(exits, 1);
  });

  testWidgets('против бота: нажатие на карту в пересдаче меняет её, «Готово» открывает поле', (tester) async {
    await pumpScreen(tester);
    await startVsBot(tester);
    expect(find.text('Пересдача'), findsOneWidget);
    expect(find.textContaining('Можно заменить ещё 2'), findsOneWidget);

    await tester.tap(find.byType(GwentCard).first);
    await settle(tester);
    expect(find.textContaining('Можно заменить ещё 1'), findsOneWidget, reason: 'карта заменена, осталась одна замена');
    await tester.tap(find.text('Готово'));
    await settle(tester);
    expect(find.byType(FieldView), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('«Готово» сразу открывает поле', (tester) async {
    await pumpScreen(tester);
    await startVsBot(tester);
    await tester.tap(find.text('Готово'));
    await settle(tester);
    expect(find.byType(FieldView), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('hot-seat: перед рукой игрока экран передачи телефона', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Вдвоём на одном телефоне'));
    await tester.pump();
    await startVsBot(tester);
    expect(find.text('Передайте телефон: игрок 1'), findsOneWidget);
    expect(find.text('Пересдача'), findsNothing, reason: 'руку нельзя показывать до подтверждения');
    await tester.tap(find.text('Я готов'));
    await settle(tester);
    expect(find.text('Пересдача'), findsOneWidget);
    await tester.tap(find.text('Готово'));
    await settle(tester);
    expect(find.text('Передайте телефон: игрок 2'), findsOneWidget);
  });

  testWidgets('колода не найдена: сообщение и выход', (tester) async {
    await pumpScreen(tester);
    bloc.add(
      const MatchStartRequested(LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'нет', deckTwo: 'нет')),
    );
    await settle(tester);
    expect(find.text('Не удалось начать партию: проверьте колоды'), findsOneWidget);
    await tester.tap(find.text('В меню'));
    expect(exits, 1);
  });

  group('экраны вокруг поля', () {
    late TestCards cards;
    setUp(() => cards = TestCards(content));

    Future<void> pumpStage(WidgetTester tester, Widget stage) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Scaffold(body: stage),
        ),
      );
    }

    testWidgets('выбор первого игрока: кнопки по местам, ответ уходит движку', (tester) async {
      final intents = <Intent>[];
      final view = viewOf(
        cards,
        phase: MatchPhase.choosingFirstPlayer,
        choice: const PendingChoice(
          seat: Seat.one,
          kind: ChoiceKind.firstPlayer,
          options: [SeatOption(Seat.one), SeatOption(Seat.two)],
        ),
      );
      await pumpStage(tester, MatchFirstPlayerStage(view: view, onIntent: intents.add));
      expect(find.text('Кто ходит первым?'), findsOneWidget);
      await tester.tap(find.text('Соперник'));
      await tester.tap(find.text('Я'));
      expect(intents, [const ChooseOption(SeatOption(Seat.two)), const ChooseOption(SeatOption(Seat.one))]);
    });

    testWidgets('выбирает соперник: ожидание без кнопок', (tester) async {
      await pumpStage(
        tester,
        MatchFirstPlayerStage(
          view: viewOf(cards, phase: MatchPhase.choosingFirstPlayer, turn: null),
          onIntent: (_) {},
        ),
      );
      expect(find.text('Соперник выбирает, кто ходит первым'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('пересдача: нажатие на карту меняет её, лимит исчерпан — карты неактивны', (tester) async {
      final intents = <Intent>[];
      final hand = [cards.unit(Row.melee), cards.unit(Row.ranged)];
      Future<void> pumpRedraw(int left, {bool done = false}) => pumpStage(
        tester,
        MatchRedrawStage(
          view: viewOf(
            cards,
            phase: MatchPhase.redraw,
            me: sideOf(cards, Seat.one, hand: hand, redrawsLeft: left, redrawDone: done),
          ),
          content: content,
          onIntent: intents.add,
        ),
      );
      await pumpRedraw(1);
      expect(find.text('Можно заменить ещё 1 карту'), findsOneWidget);
      await tester.tap(find.byType(GwentCard).first);
      expect(intents, [RedrawCard(hand.first.id)]);
      await tester.tap(find.text('Готово'));
      expect(intents.last, const FinishRedraw());

      await pumpRedraw(0);
      expect(find.text('Можно заменить ещё 0 карт'), findsOneWidget);
      await pumpRedraw(0, done: true);
      expect(find.text('Ждём, пока соперник закончит пересдачу'), findsOneWidget);
    });

    testWidgets('итог: победа, поражение и ничья с счётом раундов и выходом', (tester) async {
      var exited = 0;
      Future<void> pumpFinished(Seat? winner) => pumpStage(
        tester,
        MatchFinishedStage(
          view: viewOf(
            cards,
            phase: MatchPhase.finished,
            turn: null,
            outcome: MatchOutcome(winner: winner, reason: MatchEndReason.crystals),
            history: const [
              RoundResult(round: 1, scores: {Seat.one: 15, Seat.two: 10}, winner: Seat.one),
              RoundResult(round: 2, scores: {Seat.one: 3, Seat.two: 8}, winner: Seat.two),
            ],
          ),
          onExit: () => exited++,
        ),
      );
      await pumpFinished(Seat.one);
      expect(find.text('Победа'), findsOneWidget);
      expect(find.text('Раунд 1: 15 : 10'), findsOneWidget);
      expect(find.text('Раунд 2: 3 : 8'), findsOneWidget);
      await tester.tap(find.text('В меню'));
      expect(exited, 1);
      await pumpFinished(Seat.two);
      expect(find.text('Поражение'), findsOneWidget);
      await pumpFinished(null);
      expect(find.text('Ничья'), findsOneWidget);
    });
  });
}
