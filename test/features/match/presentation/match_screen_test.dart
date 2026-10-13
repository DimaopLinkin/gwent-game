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
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_screen.dart';
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/overlays/match_result_view.dart';
import 'package:gwent/src/features/match/presentation/overlays/pause_layers.dart';
import 'package:gwent/src/features/match/presentation/start/handover_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_intro_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_toss_view.dart';
import 'package:gwent/src/features/match/presentation/start/redraw_view.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' as history;
import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Deck, Row;

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/match_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late InMemoryDeckRepository decks;
  late InMemoryMatchHistoryRepository matches;
  late MatchBloc bloc;
  late int exits;

  setUpAll(() async {
    content = await loadBaseContent();
    await loadDesignFonts();
  });

  setUp(() {
    exits = 0;
    matches = InMemoryMatchHistoryRepository();
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
        RecordMatch(matches, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator()),
      ),
    );
    addTearDown(bloc.close);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    LocalMatchMode mode = LocalMatchMode.vsBot,
    bool preselect = true,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final setup = MatchSetupCubit(WatchDecks(decks), mode: mode, preselect: preselect);
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
    // Предвыбор ставит на оба места первую колоду списка; играть разными фракциями интереснее.
    if (preselect) {
      setup
        ..selectDeck(Seat.one, 'skellige')
        ..selectDeck(Seat.two, 'monsters');
      await tester.pump();
      await tester.pump();
    }
  }

  /// Партия идёт на настоящем столе с таймерами и потоками: ждём настоящее время, а не фальшивые часы.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    // Состояние доходит до виджетов через потоки событий и держателя: нужны лишние кадры.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump();
  }

  /// Нажимает на экран, пока он нейтральный (знакомство, жребий), и ждёт ответа стола.
  Future<void> skipIntroAndToss(WidgetTester tester) async {
    await settle(tester);
    expect(find.byType(MatchIntroView), findsOneWidget);
    await tester.tap(find.byType(MatchIntroView));
    await settle(tester);
    if (find.byType(MatchTossView).evaluate().isNotEmpty) {
      await tester.tap(find.byType(MatchTossView));
      await settle(tester);
    }
  }

  Future<void> startAndSkip(WidgetTester tester) async {
    await tester.tap(find.text('Начать партию'));
    await skipIntroAndToss(tester);
  }

  Future<void> endBanners(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('выбор колод', () {
    testWidgets('против бота: колоды выбраны сразу, подпись второй колоды «Колода бота»', (tester) async {
      await pumpScreen(tester);
      expect(find.text('Новая партия'), findsOneWidget);
      expect(find.text('Колода бота'), findsOneWidget);
      expect(find.text('Колода второго игрока'), findsNothing);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Начать партию')).onPressed, isNotNull);
    });

    testWidgets('вдвоём на одном телефоне: подпись «Колода второго игрока», переключателя режима нет', (tester) async {
      await pumpScreen(tester, mode: LocalMatchMode.hotSeat);
      expect(find.text('Колода второго игрока'), findsOneWidget);
      expect(find.text('Колода бота'), findsNothing);
      expect(find.text('Вдвоём на одном телефоне'), findsNothing);
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

    testWidgets('«В меню» на экране выбора уходит из партии', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('В меню'));
      expect(exits, 1);
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
  });

  group('начало партии против бота', () {
    testWidgets('системное «назад» посреди партии не выходит молча, до старта и после итога выходит', (tester) async {
      bool canPop() => tester
          .widgetList<PopScope>(find.descendant(of: find.byType(MatchScreen), matching: find.byType(PopScope)))
          .first
          .canPop;

      await pumpScreen(tester);
      expect(canPop(), isTrue, reason: 'выбор колод');

      await tester.tap(find.text('Начать партию'));
      await settle(tester);
      expect(find.byType(MatchIntroView), findsOneWidget);
      expect(canPop(), isFalse, reason: 'знакомство');

      await skipIntroAndToss(tester);
      expect(canPop(), isFalse, reason: 'пересдача');
    });

    testWidgets('сначала знакомство: «ПРОТИВ», фракции и колоды обоих; руки не видно', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Начать партию'));
      await settle(tester);

      expect(find.byType(MatchIntroView), findsOneWidget);
      expect(find.text('ПРОТИВ'), findsOneWidget);
      expect(find.text('Скеллиге'), findsOneWidget);
      expect(find.text('Чудовища'), findsOneWidget);
      expect(find.textContaining('«skellige»', findRichText: true), findsOneWidget);
      expect(find.textContaining('«monsters»', findRichText: true), findsOneWidget);
      expect(find.text('Вы'), findsOneWidget);
      expect(find.text('Противник'), findsOneWidget);
      expect(find.text('Пересдача'), findsNothing);
      // Знакомство держит свою анимацию до конца: дожидаемся и убеждаемся, что время тоже ведёт дальше.
      await tester.pump(MatchIntroView.duration);
      // Конец знакомства рождается в кадре анимации: событие доходит до держателя и обратно за два ожидания.
      await settle(tester);
      await settle(tester);
      expect(find.byType(MatchIntroView), findsNothing);
    });

    testWidgets('нажатие пропускает знакомство; затем пересдача: карта меняется, «Готово» открывает поле', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startAndSkip(tester);
      expect(find.text('Пересдача'), findsOneWidget);
      expect(find.textContaining('Можно заменить: 2'), findsOneWidget);

      await tester.tap(find.byType(GwentCard).first);
      await settle(tester);
      expect(find.textContaining('Можно заменить: 1'), findsOneWidget, reason: 'карта заменена, осталась одна замена');
      await tester.tap(find.text('Готово'));
      await settle(tester);
      expect(find.byType(FieldView), findsOneWidget);
      await endBanners(tester);
    });

    testWidgets('«Готово» сразу открывает поле', (tester) async {
      await pumpScreen(tester);
      await startAndSkip(tester);
      await tester.tap(find.text('Готово'));
      await settle(tester);
      expect(find.byType(FieldView), findsOneWidget);
      await endBanners(tester);
    });

    testWidgets('сдача: пауза, «Сдаться», подтверждение — экран итога с поражением и записью в историю', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startAndSkip(tester);
      await tester.tap(find.text('Готово'));
      await settle(tester);
      await endBanners(tester);

      await tester.tap(find.bySemanticsLabel('Пауза'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Сдаться'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Сдаться?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(SurrenderConfirmLayer), matching: find.text('Сдаться')));
      await settle(tester);

      expect(find.byType(MatchResultView), findsOneWidget);
      expect(find.text('Поражение'), findsOneWidget);
      expect(matches.records.single.outcome, history.MatchOutcome.defeat);
    });

    testWidgets('реванш: экран итога возвращает к знакомству с теми же колодами', (tester) async {
      await pumpScreen(tester);
      await startAndSkip(tester);
      await tester.tap(find.text('Готово'));
      await settle(tester);
      await endBanners(tester);
      bloc.add(const MatchIntentSubmitted(Resign()));
      await settle(tester);

      expect(find.byType(MatchResultView), findsOneWidget);
      await tester.tap(find.text('Реванш'));
      await settle(tester);
      expect(find.byType(MatchIntroView), findsOneWidget);
    });

    testWidgets('«В меню» на экране итога уходит из партии', (tester) async {
      await pumpScreen(tester);
      await startAndSkip(tester);
      await tester.tap(find.text('Готово'));
      await settle(tester);
      await endBanners(tester);
      bloc.add(const MatchIntentSubmitted(Resign()));
      await settle(tester);

      await tester.tap(find.text('В меню'));
      expect(exits, 1);
    });
  });

  group('начало партии вдвоём на одном телефоне', () {
    testWidgets('руку нельзя показывать до подтверждения: сначала передача телефона', (tester) async {
      await pumpScreen(tester, mode: LocalMatchMode.hotSeat);
      await startAndSkip(tester);
      expect(find.byType(MatchHandoverView), findsOneWidget);
      expect(find.text('Передайте телефон:'), findsOneWidget);
      expect(find.text('Игрок 1'), findsWidgets);
      expect(find.text('Пересдача'), findsNothing);

      await tester.tap(find.text('Я готов'));
      await settle(tester);
      expect(find.byType(MatchRedrawView), findsOneWidget);
      expect(find.text('Пересдача'), findsOneWidget);
      await tester.tap(find.text('Готово'));
      await settle(tester);
      expect(find.byType(MatchHandoverView), findsOneWidget);
      expect(find.text('Игрок 2'), findsWidgets);
    });

    testWidgets('в hot-seat знакомство называет игроков по номеру', (tester) async {
      await pumpScreen(tester, mode: LocalMatchMode.hotSeat);
      await tester.tap(find.text('Начать партию'));
      await settle(tester);
      expect(find.text('Игрок 1'), findsWidgets);
      expect(find.text('Игрок 2'), findsWidgets);
    });
  });

  group('сбои', () {
    testWidgets('стол сломался: сообщение об ошибке и выход в меню', (tester) async {
      await pumpScreen(tester);
      final table = _FakeTable();
      bloc.add(MatchSessionOpened(_session(table, content)));
      await settle(tester);
      table.fail(StateError('бот сломался'));
      await settle(tester);

      expect(find.text('Партия прервалась из-за ошибки'), findsOneWidget);
      await tester.tap(find.text('В меню'));
      expect(exits, 1);
    });
  });
}

/// Начатая партия на поддельном столе.
MatchSession _session(MatchTable table, GameContent content) => MatchSession(
  mode: history.MatchMode.ai,
  table: table,
  content: content,
  factionIds: const {Seat.one: 'skellige', Seat.two: 'monsters'},
);

/// Стол, обновления которого присылает тест.
final class _FakeTable implements MatchTable {
  final StreamController<TableUpdate> _updates = StreamController();

  void fail(Object error) => _updates.add(TableFailed(error));

  @override
  Set<Seat> get localSeats => const {Seat.one};

  @override
  Stream<TableUpdate> get updates => _updates.stream;

  @override
  void submit(Seat seat, Intent intent) {}

  @override
  Future<void> close() => _updates.close();
}
