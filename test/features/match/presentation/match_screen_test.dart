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
import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/application/get_active_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/application/set_active_deck.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/match/application/choose_opponent_deck.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match/presentation/match_bloc.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_screen.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent/src/features/match/presentation/overlays/match_result_view.dart';
import 'package:gwent/src/features/match/presentation/overlays/pause_layers.dart';
import 'package:gwent/src/features/match/presentation/setup/bot_difficulty_text.dart';
import 'package:gwent/src/features/match/presentation/start/handover_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_intro_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_toss_view.dart';
import 'package:gwent/src/features/match/presentation/start/redraw_view.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' as history;
import 'package:gwent/src/features/settings/application/load_bot_difficulty.dart';
import 'package:gwent/src/features/settings/application/save_bot_difficulty.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;
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
  late List<String> edited;
  late MatchSetupCubit setupCubit;
  late List<MatchEvent> events;
  late AppLocalizations l10n;

  setUpAll(() async {
    content = await loadBaseContent();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    await loadDesignFonts();
  });

  setUp(() {
    events = [];
    // Держатель запоминает наблюдателя при создании, поэтому ставим его до `MatchBloc`.
    final observer = Bloc.observer;
    Bloc.observer = _EventObserver(events);
    addTearDown(() => Bloc.observer = observer);
    exits = 0;
    edited = [];
    matches = InMemoryMatchHistoryRepository();
    decks = InMemoryDeckRepository([
      realDeck(content, Faction.monsters, id: 'monsters'),
      realDeck(content, Faction.northernRealms, id: 'realms'),
    ]);
    bloc = MatchBloc(
      StartMatch(
        LoadGameContent(AssetContentSource.basePack(rootBundle)),
        decks,
        FixedSeedGenerator(3),
        createBot: plainGreedyBot,
        botThinkTime: Duration.zero,
      ),
      RecordFinishedMatch(
        RecordMatch(matches, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator()),
      ),
    );
    addTearDown(bloc.close);
  });

  /// Выбор колод читает хранилище и пакет: даём им отработать.
  Future<void> settleSetup(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    LocalMatchMode mode = LocalMatchMode.vsBot,
    VoidCallback? onSettings,
    Size size = const Size(390, 844),
    bool passDifficulty = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final rules = GameContentDeckRulesSource(LoadGameContent(AssetContentSource.basePack(rootBundle)));
    final lock = DeckSelectionLock();
    final getActiveDeck = GetActiveDeck(
      decks,
      rules,
      CreateStarterDeck(decks, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator()),
      lock,
    );
    final settings = InMemorySettingsRepository();
    final setup = MatchSetupCubit(
      watchDecks: WatchDecks(decks),
      loadDeckRules: LoadDeckRules(rules),
      getActiveDeck: getActiveDeck,
      setActiveDeck: SetActiveDeck(decks, rules, lock),
      chooseOpponentDeck: ChooseOpponentDeck(rules, FixedSeedGenerator(3)),
      loadBotDifficulty: LoadBotDifficulty(settings),
      saveBotDifficulty: SaveBotDifficulty(settings),
      mode: mode,
    );
    addTearDown(setup.close);
    setupCubit = setup;
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
          home: MatchScreen(onExit: () => exits++, onEditDeck: edited.add, onSettings: onSettings),
        ),
      ),
    );
    await settleSetup(tester);
    // Против бота выбор начинается со сложности: остальные тесты начинаются с выбора фракции.
    if (mode == LocalMatchMode.vsBot && passDifficulty) {
      await tester.tap(find.text(l10n.difficultySelectConfirm));
      await settleSetup(tester);
    }
  }

  /// Проходит два шага выбора для места: фракция с ключом [factionKey], потом предвыбранная колода.
  Future<void> chooseSeat(WidgetTester tester, String factionKey) async {
    final ready = setupCubit.state as MatchSetupReady;
    setupCubit.showFaction(ready.rules.factionInfos.indexWhere((faction) => faction.key == factionKey));
    await tester.pump();
    await tester.tap(find.text(l10n.factionSelectConfirm));
    await settleSetup(tester);
    final last = (setupCubit.state as MatchSetupReady).isLastSeat;
    await tester.tap(find.text(last ? l10n.deckSelectPlay : l10n.deckSelectNext));
    await settleSetup(tester);
  }

  /// Выбор колод до конца: игрок — Чудовища, бот или второй игрок — Королевства Севера.
  Future<void> playSetup(WidgetTester tester) async {
    await chooseSeat(tester, 'monsters');
    if ((setupCubit.state is MatchSetupReady) && (setupCubit.state as MatchSetupReady).seat == Seat.two) {
      await chooseSeat(tester, 'northern_realms');
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
    await playSetup(tester);
    await skipIntroAndToss(tester);
  }

  Future<void> endBanners(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('выбор фракции и колоды', () {
    testWidgets('против бота: сложность, фракция, колода; второго места нет', (tester) async {
      await pumpScreen(tester, passDifficulty: false);
      expect(find.text(l10n.setupStep(1, 3).toUpperCase()), findsOneWidget);
      expect(find.text(l10n.difficultySelectTitle), findsOneWidget);
      for (final difficulty in BotDifficulty.values) {
        expect(find.text(botDifficultyName(l10n, difficulty)), findsOneWidget);
      }
      await tester.tap(find.text(botDifficultyName(l10n, BotDifficulty.deathMatch)));
      await tester.pump();
      await tester.tap(find.text(l10n.difficultySelectConfirm));
      await settleSetup(tester);

      expect(find.text(l10n.setupStep(2, 3).toUpperCase()), findsOneWidget);
      expect(find.text(l10n.factionSelectConfirm), findsOneWidget);

      setupCubit.showFaction(2);
      await tester.pump();
      await tester.tap(find.text(l10n.factionSelectConfirm));
      await settleSetup(tester);
      expect(find.text(l10n.setupStep(3, 3).toUpperCase()), findsOneWidget);
      expect(find.text(l10n.deckSelectTitle), findsOneWidget, reason: 'после фракции сразу колоды, без выбора лидера');
      expect(find.text(l10n.deckSelectPlay), findsOneWidget);
      expect(find.text('monsters'), findsOneWidget, reason: 'колода выбранной фракции');
      expect(find.text('realms'), findsNothing, reason: 'колод других фракций в списке нет');
    });

    testWidgets('вдвоём на одном телефоне: после первого места выбирает второй игрок', (tester) async {
      await pumpScreen(tester, mode: LocalMatchMode.hotSeat);
      expect(find.text(l10n.setupStepSeat(l10n.playerNumbered(1), 1, 2).toUpperCase()), findsOneWidget);

      await chooseSeat(tester, 'monsters');

      expect(find.text(l10n.setupStepSeat(l10n.playerNumbered(2), 1, 2).toUpperCase()), findsOneWidget);
      expect(find.byType(MatchIntroView), findsNothing);
    });

    testWidgets('«Назад» на первом шаге выходит из выбора, дальше — на шаг назад', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text(l10n.factionSelectConfirm));
      await settleSetup(tester);
      expect(find.text(l10n.deckSelectTitle), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(l10n.setupBack));
      await settleSetup(tester);
      expect(find.text(l10n.factionSelectConfirm), findsOneWidget);
      expect(exits, 0);

      await tester.tap(find.bySemanticsLabel(l10n.setupBack));
      await settleSetup(tester);
      expect(find.text(l10n.difficultySelectConfirm), findsOneWidget, reason: 'против бота перед фракцией сложность');
      expect(exits, 0);

      await tester.tap(find.bySemanticsLabel(l10n.setupBack));
      expect(exits, 1);
    });

    testWidgets('«Изменить» у колоды передаёт её в конструктор', (tester) async {
      await pumpScreen(tester);
      setupCubit.showFaction(2);
      await tester.pump();
      await tester.tap(find.text(l10n.factionSelectConfirm));
      await settleSetup(tester);

      await tester.tap(find.text(l10n.deckSelectEdit));

      expect(edited, ['monsters']);
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
      expect(canPop(), isTrue, reason: 'выбор фракции');

      await playSetup(tester);
      await settle(tester);
      expect(find.byType(MatchIntroView), findsOneWidget);
      expect(canPop(), isFalse, reason: 'знакомство');

      await skipIntroAndToss(tester);
      expect(canPop(), isFalse, reason: 'пересдача');
    });

    testWidgets('сначала знакомство: «ПРОТИВ», фракции и колоды обоих; руки не видно', (tester) async {
      await pumpScreen(tester);
      await playSetup(tester);
      await settle(tester);

      expect(find.byType(MatchIntroView), findsOneWidget);
      expect(find.text('ПРОТИВ'), findsOneWidget);
      // Фракция бота случайна (ADR 0021): игрок за Чудовищ, колода бота названа по её фракции.
      final botDeck = (bloc.state as MatchIntro).roster.players[Seat.two]!.deckName!;
      expect(find.text('Чудовища'), findsWidgets);
      expect(find.textContaining('«monsters»', findRichText: true), findsOneWidget);
      expect(find.textContaining('«$botDeck»', findRichText: true), findsOneWidget);
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
      await endBanners(tester);

      expect(find.byType(MatchResultView), findsOneWidget);
      expect(find.text('Поражение'), findsOneWidget);
      expect(matches.records.single.outcome, history.MatchOutcome.defeat);
    });

    testWidgets('пауза матча сообщает держателю партии: открыта — бот стоит, закрыта — продолжает', (tester) async {
      await pumpScreen(tester);
      await startAndSkip(tester);
      await tester.tap(find.text('Готово'));
      await settle(tester);
      await endBanners(tester);

      await tester.tap(find.bySemanticsLabel('Пауза'));
      await tester.pump(const Duration(milliseconds: 250));
      // Правила и подтверждение сдачи тоже пауза: бот не оживает, пока игрок листает меню.
      await tester.tap(find.text('Сдаться'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(events.whereType<MatchPauseChanged>().map((event) => event.paused), [true]);

      await tester.tap(find.text('Отмена'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Продолжить'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(events.whereType<MatchPauseChanged>().map((event) => event.paused), [true, false]);
    });

    testWidgets('пауза: «Настройки» открывают настройки, партия остаётся на паузе', (tester) async {
      var opened = 0;
      await pumpScreen(tester, onSettings: () => opened++);
      await startAndSkip(tester);
      await tester.tap(find.text('Готово'));
      await settle(tester);
      await endBanners(tester);

      await tester.tap(find.bySemanticsLabel('Пауза'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Настройки'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(opened, 1);
      expect(find.byType(PauseMenuLayer), findsOneWidget);
    });

    testWidgets('реванш: экран итога возвращает к знакомству с теми же колодами', (tester) async {
      await pumpScreen(tester);
      await startAndSkip(tester);
      await tester.tap(find.text('Готово'));
      await settle(tester);
      await endBanners(tester);
      bloc.add(const MatchIntentSubmitted(Resign()));
      await settle(tester);
      await endBanners(tester);

      expect(find.byType(MatchResultView), findsOneWidget);
      await tester.pump(MatchResultView.sheetSlide);
      await tester.tap(find.text('Реванш'));
      await settle(tester);
      expect(find.byType(MatchIntroView), findsOneWidget);
    });

    testWidgets('«Другая колода» на экране итога открывает выбор с фракции, на которой играли', (tester) async {
      await pumpScreen(tester);
      await startAndSkip(tester);
      await tester.tap(find.text('Готово'));
      await settle(tester);
      await endBanners(tester);
      bloc.add(const MatchIntentSubmitted(Resign()));
      await settle(tester);
      await endBanners(tester);
      await tester.pump(MatchResultView.sheetSlide);

      await tester.tap(find.text(l10n.matchResultChangeDeck));
      await settleSetup(tester);

      expect(bloc.state, isA<MatchIdle>());
      expect(find.byType(MatchResultView), findsNothing);
      expect(find.text(l10n.setupStep(2, 3).toUpperCase()), findsOneWidget, reason: 'сложность уже выбрана');
      expect((setupCubit.state as MatchSetupReady).faction.key, 'monsters');
      expect(exits, 0);

      // Новый выбор доходит до новой партии.
      await chooseSeat(tester, 'northern_realms');
      await skipIntroAndToss(tester);
      expect(find.byType(MatchRedrawView), findsOneWidget);
    });

    testWidgets('«В меню» на экране итога уходит из партии', (tester) async {
      await pumpScreen(tester);
      await startAndSkip(tester);
      await tester.tap(find.text('Готово'));
      await settle(tester);
      await endBanners(tester);
      bloc.add(const MatchIntentSubmitted(Resign()));
      await settle(tester);
      await endBanners(tester);
      await tester.pump(MatchResultView.sheetSlide);

      await tester.tap(find.text('В меню'));
      expect(exits, 1);
    });
  });

  group('пересдача', () {
    testWidgets('после последней замены рука с пришедшей картой держится, потом экран уходит дальше', (tester) async {
      await pumpScreen(tester);
      await startAndSkip(tester);
      expect(find.byType(MatchRedrawView), findsOneWidget);

      await tester.tap(find.byType(GwentCard).first);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byType(GwentCard).at(1));
      await settle(tester);

      expect(find.text('Можно заменить: 0'), findsOneWidget, reason: 'замены кончились, а экран ещё на руке');
      expect(find.byType(MatchRedrawView), findsOneWidget);
      expect(find.byType(MatchRedrawWaitView), findsNothing);
      expect(find.byType(FieldView), findsNothing);

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(find.byType(MatchRedrawView), findsNothing, reason: 'выдержка кончилась: ожидание соперника или поле');
      await tester.pumpWidget(const SizedBox());
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
      await playSetup(tester);
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

/// Наблюдатель, который собирает события держателей состояния.
final class _EventObserver extends BlocObserver {
  _EventObserver(this._events);

  final List<MatchEvent> _events;

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    if (event is MatchEvent) _events.add(event);
    super.onEvent(bloc, event);
  }
}
