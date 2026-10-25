import 'package:flutter/material.dart' hide Intent, Row;
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/domain/rematch_offer.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/match/presentation/overlays/match_result_view.dart';
import 'package:gwent/src/features/match/presentation/overlays/round_summary_view.dart';
import 'package:gwent/src/features/match/presentation/overlays/rules_view.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../../support/fonts.dart';
import '../../../../support/localized_app.dart';
import '../../../../support/match_fixtures.dart';
import '../../../../support/screen_guards.dart';
import '../field/field_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late TestCards cards;

  setUpAll(() async {
    content = await loadBaseContent();
    await loadDesignFonts();
  });
  setUp(() => cards = TestCards(content));

  Future<void> pumpView(WidgetTester tester, Widget view, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(view));
  }

  group('итог раунда', () {
    RoundSummary summary({
      RoundOutcome outcome = RoundOutcome.win,
      int scoreMine = 17,
      int scoreOpponent = 9,
      int crystalsMine = 2,
      int crystalsOpponent = 1,
      List<FactionMark> marks = const [],
      Faction mine = Faction.skellige,
      Faction opponent = Faction.monsters,
    }) => RoundSummary(
      round: 2,
      mineSeat: Seat.one,
      scoreMine: scoreMine,
      scoreOpponent: scoreOpponent,
      outcome: outcome,
      crystalsMine: crystalsMine,
      crystalsOpponent: crystalsOpponent,
      mineFaction: mine,
      opponentFaction: opponent,
      marks: marks,
    );

    Future<void> pumpSummary(
      WidgetTester tester,
      RoundSummary summary, {
      bool hotSeat = false,
      VoidCallback? onDismissed,
    }) => pumpView(
      tester,
      RoundSummaryView(
        summary: summary,
        roster: rosterOf(cards, hotSeat: hotSeat),
        onDismissed: onDismissed ?? () {},
      ),
    );

    testWidgets('победа: заголовок, счёт, подписи сторон и подсказка', (tester) async {
      await pumpSummary(tester, summary());
      expect(find.text('РАУНД 2 · ИТОГ'), findsOneWidget);
      expect(find.text('Вы выиграли раунд'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('Вы'), findsOneWidget);
      expect(find.text('Противник'), findsOneWidget);
      expect(find.text('Нажмите, чтобы продолжить'), findsOneWidget);
      await tester.pump(BreakingGem.duration);
    });

    testWidgets('поражение и ничья называются своими словами', (tester) async {
      await pumpSummary(tester, summary(outcome: RoundOutcome.loss, scoreMine: 3, scoreOpponent: 8));
      expect(find.text('Противник выиграл раунд'), findsOneWidget);
      await pumpSummary(tester, summary(outcome: RoundOutcome.draw, scoreMine: 8, scoreOpponent: 8));
      expect(find.text('Ничья'), findsOneWidget);
      await tester.pump(BreakingGem.duration);
    });

    testWidgets('в hot-seat назван победитель по номеру', (tester) async {
      await pumpSummary(tester, summary(), hotSeat: true);
      expect(find.text('Игрок 1 выиграл раунд'), findsOneWidget);
      await pumpSummary(tester, summary(outcome: RoundOutcome.loss), hotSeat: true);
      expect(find.text('Игрок 2 выиграл раунд'), findsOneWidget);
      await tester.pump(BreakingGem.duration);
    });

    testWidgets('сработавшие способности фракций перечислены с названием фракции', (tester) async {
      await pumpSummary(
        tester,
        summary(
          marks: const [
            FactionMark(seat: Seat.one, mine: true, faction: Faction.nilfgaard, kind: FactionMarkKind.wonTie),
            FactionMark(seat: Seat.two, mine: false, faction: Faction.monsters, kind: FactionMarkKind.unitStays),
            FactionMark(seat: Seat.one, mine: true, faction: Faction.northernRealms, kind: FactionMarkKind.extraCard),
          ],
        ),
      );
      expect(find.text('СПОСОБНОСТИ ФРАКЦИЙ'), findsOneWidget);
      expect(find.textContaining('победа при ничьей'), findsOneWidget);
      expect(find.textContaining('карта остаётся на поле'), findsOneWidget);
      expect(find.textContaining('+1 карта'), findsOneWidget);
      await tester.pump(BreakingGem.duration);
    });

    testWidgets('без способностей блока нет', (tester) async {
      await pumpSummary(tester, summary());
      expect(find.text('СПОСОБНОСТИ ФРАКЦИЙ'), findsNothing);
      await tester.pump(BreakingGem.duration);
    });

    testWidgets('нажатие в любом месте закрывает итог', (tester) async {
      var dismissed = 0;
      await pumpSummary(tester, summary(), onDismissed: () => dismissed++);
      await tester.tapAt(const Offset(195, 400));
      expect(dismissed, 1);
      await tester.pump(BreakingGem.duration);
    });

    testWidgets('кристаллы подписаны для диктора: сколько осталось из скольких', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSummary(tester, summary());
      expect(find.bySemanticsLabel(RegExp('Кристаллов: 2 из 2')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Кристаллов: 1 из 2')), findsWidgets);
      await tester.pump(BreakingGem.duration);
      semantics.dispose();
    });

    testWidgets('трескается кристалл того, кто проиграл раунд; при ничьей — оба', (tester) async {
      await pumpSummary(tester, summary());
      expect(find.byType(BreakingGem), findsOneWidget);
      await pumpSummary(tester, summary(outcome: RoundOutcome.loss, crystalsMine: 1, crystalsOpponent: 2));
      expect(find.byType(BreakingGem), findsOneWidget);
      await pumpSummary(tester, summary(outcome: RoundOutcome.draw, crystalsMine: 1));
      expect(find.byType(BreakingGem), findsNWidgets(2));
      await tester.pump(BreakingGem.duration);
    });

    testWidgets('при «уменьшить движение» кристалл сразу пустой, анимации нет', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpSummary(tester, summary());
      final gem = find.byType(BreakingGem);
      expect(gem, findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('итог матча', () {
    PlayerView finished({Seat? winner, List<RoundResult>? history, Seat viewer = Seat.one}) => PlayerView(
      viewer: viewer,
      phase: MatchPhase.finished,
      round: 3,
      me: sideOf(cards, viewer),
      opponent: sideOf(cards, viewer.opponent),
      weather: const [],
      history:
          history ??
          const [
            RoundResult(round: 1, scores: {Seat.one: 15, Seat.two: 10}, winner: Seat.one),
            RoundResult(round: 2, scores: {Seat.one: 3, Seat.two: 8}, winner: Seat.two),
            RoundResult(round: 3, scores: {Seat.one: 9, Seat.two: 9}, winner: null),
          ],
      outcome: MatchOutcome(winner: winner, reason: MatchEndReason.crystals),
    );

    Future<void> pumpResult(
      WidgetTester tester,
      PlayerView view, {
      bool hotSeat = false,
      VoidCallback? onExit,
      VoidCallback? onRematch,
      VoidCallback? onChangeDeck,
      Size size = const Size(390, 844),
    }) async {
      await pumpView(
        tester,
        MatchResultView(
          view: view,
          roster: rosterOf(cards, hotSeat: hotSeat),
          onExit: onExit ?? () {},
          onRematch: onRematch,
          onChangeDeck: onChangeDeck,
        ),
        size: size,
      );
      // Лист выезжает из-под экрана.
      await tester.pump();
      await tester.pump(MatchResultView.sheetSlide);
    }

    testWidgets('победа: «Победа», счёт раундов и таблица по раундам', (tester) async {
      await pumpResult(tester, finished(winner: Seat.one));
      expect(find.text('Победа'), findsOneWidget);
      expect(find.text('· 1 : 1'), findsOneWidget);
      expect(find.text('РАУНД'), findsOneWidget);
      expect(find.text('ПОБЕДИТЕЛЬ'), findsOneWidget);
      expect(find.text('Раунд 1'), findsOneWidget);
      expect(find.text('Раунд 3'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Ничья'), findsOneWidget, reason: 'третий раунд сыгран вничью');
    });

    testWidgets('поражение и ничья', (tester) async {
      await pumpResult(tester, finished(winner: Seat.two));
      expect(find.text('Поражение'), findsOneWidget);
      await pumpResult(tester, finished());
      expect(find.text('Ничья'), findsWidgets);
    });

    testWidgets('партия закончилась сдачей до третьего раунда: несыгранные раунды в таблице пустые', (tester) async {
      await pumpResult(
        tester,
        finished(
          winner: Seat.two,
          history: const [
            RoundResult(round: 1, scores: {Seat.one: 15, Seat.two: 10}, winner: Seat.one),
          ],
        ),
      );
      expect(find.text('Раунд 2'), findsOneWidget);
      expect(find.text('Раунд 3'), findsOneWidget);
      expect(find.text('· 1 : 0'), findsOneWidget);
    });

    testWidgets('в hot-seat назван победитель, а заголовок победный', (tester) async {
      await pumpResult(tester, finished(winner: Seat.two), hotSeat: true);
      expect(find.text('Победил Игрок 2'), findsOneWidget);
      expect(find.text('Победа'), findsOneWidget);
      expect(find.text('Игрок 1'), findsWidgets);
      expect(find.text('Игрок 2'), findsWidgets);
    });

    testWidgets('экран итога глазами второго места считает раунды с его стороны', (tester) async {
      await pumpResult(tester, finished(winner: Seat.two, viewer: Seat.two));
      expect(find.text('· 1 : 1'), findsOneWidget);
      expect(find.text('Победа'), findsOneWidget);
    });

    testWidgets('«Реванш» и «В меню» вызывают свои действия', (tester) async {
      var rematch = 0;
      var exit = 0;
      await pumpResult(
        tester,
        finished(winner: Seat.one),
        onRematch: () => rematch++,
        onExit: () => exit++,
      );
      await tester.ensureVisible(find.text('Реванш'));
      await tester.tap(find.text('Реванш'));
      await tester.tap(find.text('В меню'));
      expect((rematch, exit), (1, 1));
    });

    testWidgets('в местной партии есть «Другая колода»: три кнопки делают каждая своё', (tester) async {
      var rematch = 0;
      var change = 0;
      var exit = 0;
      await pumpResult(
        tester,
        finished(winner: Seat.one),
        onRematch: () => rematch++,
        onChangeDeck: () => change++,
        onExit: () => exit++,
      );
      await tester.tap(find.text('Реванш'));
      await tester.tap(find.text('Другая колода'));
      await tester.tap(find.text('В меню'));
      expect((rematch, change, exit), (1, 1, 1));
      expectNoFallbackTextStyle(tester);
    });

    testWidgets('«Другая колода» на узком экране не вылезает за него и не обрезается', (tester) async {
      await pumpResult(
        tester,
        finished(winner: Seat.one),
        onRematch: () {},
        onChangeDeck: () {},
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getBottomLeft(find.text('В меню')).dy, lessThanOrEqualTo(568));
      expect(tester.getTopRight(find.text('Другая колода')).dx, lessThanOrEqualTo(320));
      expect(tester.widget<Text>(find.text('Другая колода')).maxLines, 2, reason: 'длинная подпись переносится');
    });

    testWidgets('без «Другой колоды» (сетевая партия) кнопки нет', (tester) async {
      await pumpResult(tester, finished(winner: Seat.one), onRematch: () {});
      expect(find.text('Другая колода'), findsNothing);
    });

    testWidgets('без реванша кнопки «Реванш» нет', (tester) async {
      await pumpResult(tester, finished(winner: Seat.one));
      expect(find.text('Реванш'), findsNothing);
      expect(find.text('В меню'), findsOneWidget);
    });

    testWidgets('с «Реваншем», «Другой колодой» и «В меню» прокручиваемая середина не ниже 400 pt', (tester) async {
      await pumpResult(
        tester,
        finished(winner: Seat.one),
        onRematch: () {},
        onChangeDeck: () {},
      );
      expect(tester.getSize(find.byType(SingleChildScrollView)).height, greaterThanOrEqualTo(400));
      expect(tester.getTopLeft(find.text('Победа')).dy, greaterThan(0), reason: 'лист не заходит под верх экрана');
    });

    testWidgets('на низком экране середина листа прокручивается без переполнения', (tester) async {
      await pumpView(
        tester,
        MatchResultView(
          view: finished(winner: Seat.one),
          roster: rosterOf(cards),
          onExit: () {},
          onRematch: () {},
        ),
        size: const Size(320, 568),
      );
      await tester.pump();
      await tester.pump(MatchResultView.sheetSlide);
      expect(tester.takeException(), isNull);
      expect(tester.getBottomLeft(find.text('В меню')).dy, lessThanOrEqualTo(568));
      await tester.scrollUntilVisible(find.text('Раунд 3'), 100, scrollable: find.byType(Scrollable));
    });

    testWidgets('лист выезжает снизу, а поле за ним затемняется на 62 %', (tester) async {
      await pumpView(
        tester,
        MatchResultView(
          view: finished(winner: Seat.one),
          roster: rosterOf(cards),
          onExit: () {},
          field: const Text('поле партии'),
        ),
      );
      expect(tester.getTopLeft(find.text('Победа')).dy, greaterThan(844), reason: 'до первого кадра лист под экраном');
      await tester.pump();
      await tester.pump(MatchResultView.sheetSlide);
      expect(tester.getTopLeft(find.text('Победа')).dy, lessThan(844 - 400));
      expect(find.text('поле партии'), findsOneWidget);
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0.62);
    });

    testWidgets('«Показать поле» опускает лист до полосы 64 pt и снимает затемнение, «К итогам» возвращает', (
      tester,
    ) async {
      await pumpView(
        tester,
        MatchResultView(
          view: finished(winner: Seat.one),
          roster: rosterOf(cards),
          onExit: () {},
          onRematch: () {},
        ),
      );
      await tester.pump();
      await tester.pump(MatchResultView.sheetSlide);
      final expandedTop = tester.getTopLeft(find.text('Победа')).dy;

      await tester.tap(find.text('Показать поле'));
      await tester.pump();
      await tester.pump(MatchResultView.sheetSlide);
      expect(find.text('К итогам'), findsOneWidget);
      expect(find.text('Показать поле'), findsNothing);
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0);
      expect(tester.getBottomLeft(find.text('Победа')).dy, lessThanOrEqualTo(844), reason: 'шапка остаётся на экране');
      expect(tester.getTopLeft(find.text('Реванш')).dy, greaterThan(844), reason: 'кнопки уходят вниз');
      expect(tester.getTopLeft(find.text('Победа')).dy, greaterThan(expandedTop));

      await tester.tap(find.text('К итогам'));
      await tester.pump();
      await tester.pump(MatchResultView.sheetSlide);
      expect(find.text('Показать поле'), findsOneWidget);
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0.62);
      expect(tester.getTopLeft(find.text('Победа')).dy, expandedTop);
    });

    testWidgets('жест вниз по шапке сворачивает лист, жест вверх разворачивает; короткий жест ничего не делает', (
      tester,
    ) async {
      await pumpView(
        tester,
        MatchResultView(
          view: finished(winner: Seat.one),
          roster: rosterOf(cards),
          onExit: () {},
          onRematch: () {},
        ),
      );
      await tester.pump();
      await tester.pump(MatchResultView.sheetSlide);

      await tester.drag(find.text('Победа'), const Offset(0, 20));
      await tester.pump();
      await tester.pump(MatchResultView.sheetSlide);
      expect(find.text('Показать поле'), findsOneWidget, reason: 'до 40 pt лист остаётся');

      await tester.drag(find.text('Победа'), const Offset(0, 80));
      await tester.pump();
      await tester.pump(MatchResultView.sheetSlide);
      expect(find.text('К итогам'), findsOneWidget);

      await tester.drag(find.text('Победа'), const Offset(0, -80));
      await tester.pump();
      await tester.pump(MatchResultView.sheetSlide);
      expect(find.text('Показать поле'), findsOneWidget);
    });

    group('реванш по сети', () {
      Future<void> pumpOnline(WidgetTester tester, RematchOffer offer, {VoidCallback? onRematch, Size? size}) async {
        await pumpView(
          tester,
          MatchResultView(
            view: finished(winner: Seat.one),
            roster: rosterOf(cards),
            onExit: () {},
            onRematch: onRematch ?? () {},
            rematch: offer,
          ),
          size: size ?? const Size(390, 844),
        );
        await tester.pump();
        await tester.pump(MatchResultView.sheetSlide);
      }

      testWidgets('предложение ещё не сделано: кнопка доступна, пояснения нет', (tester) async {
        var taps = 0;
        await pumpOnline(tester, RematchOffer.idle, onRematch: () => taps++);
        await tester.tap(find.text('Реванш'));
        expect(taps, 1);
        expect(find.textContaining(' с'), findsNothing);
      });

      testWidgets('предложил игрок: сколько осталось ждать, секунды идут, кнопка не нажимается', (tester) async {
        var taps = 0;
        await pumpOnline(
          tester,
          const RematchOffer(RematchStage.requested, window: Duration(seconds: 30)),
          onRematch: () => taps++,
        );
        expect(find.text('Ждём ответа соперника · 30 с'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Ждём ответа соперника · 27 с'), findsOneWidget);
        await tester.tap(find.text('Реванш'), warnIfMissed: false);
        expect(taps, 0);
        // Отсчёт не уходит ниже нуля.
        await tester.pump(const Duration(seconds: 40));
        expect(find.text('Ждём ответа соперника · 0 с'), findsOneWidget);
      });

      testWidgets('предложил соперник: можно согласиться', (tester) async {
        var taps = 0;
        await pumpOnline(
          tester,
          const RematchOffer(RematchStage.invited, window: Duration(seconds: 20)),
          onRematch: () => taps++,
        );
        expect(find.text('Соперник предлагает реванш · 20 с'), findsOneWidget);
        await tester.tap(find.text('Реванш'));
        expect(taps, 1);
      });

      testWidgets('время вышло или соперник ушёл: сказано об этом, отсчёта нет, кнопка недоступна', (tester) async {
        var taps = 0;
        await pumpOnline(tester, const RematchOffer(RematchStage.expired), onRematch: () => taps++);
        expect(find.text('Время на ответ вышло, реванша не будет'), findsOneWidget);
        await tester.tap(find.text('Реванш'), warnIfMissed: false);
        expect(taps, 0);
        await pumpOnline(tester, const RematchOffer(RematchStage.opponentGone), onRematch: () => taps++);
        expect(find.text('Соперник ушёл, реванша не будет'), findsOneWidget);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('новое состояние предложения запускает отсчёт заново; на узком экране без переполнения', (
        tester,
      ) async {
        await pumpOnline(
          tester,
          const RematchOffer(RematchStage.invited, window: Duration(seconds: 30)),
          size: const Size(320, 568),
        );
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('Соперник предлагает реванш · 25 с'), findsOneWidget);
        await pumpOnline(
          tester,
          const RematchOffer(RematchStage.requested, window: Duration(seconds: 30)),
          size: const Size(320, 568),
        );
        expect(find.text('Ждём ответа соперника · 30 с'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectNoFallbackTextStyle(tester);
      });
    });

    testWidgets('за листом поле не принимает касаний', (tester) async {
      var taps = 0;
      await pumpView(
        tester,
        MatchResultView(
          view: finished(winner: Seat.one),
          roster: rosterOf(cards),
          onExit: () {},
          field: Center(
            child: GestureDetector(onTap: () => taps++, child: const Text('поле партии')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(MatchResultView.sheetSlide);
      await tester.tap(find.text('поле партии'), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  group('справочник правил', () {
    testWidgets('разделы: цель, ряды, погода, способности, фракции с названиями из пакета', (tester) async {
      await pumpView(tester, RulesView(roster: rosterOf(cards), onBack: () {}));
      expect(find.text('Правила'), findsOneWidget);
      expect(find.text('Цель'), findsOneWidget);
      for (final title in ['Ряды', 'Погода', 'Способности', 'Фракции']) {
        await tester.scrollUntilVisible(find.text(title), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text(title), findsOneWidget);
      }
      for (final faction in ['Королевства Севера', 'Нильфгаард', 'Чудовища', "Скоя'таэли", 'Скеллиге']) {
        await tester.scrollUntilVisible(find.text(faction), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text(faction), findsOneWidget);
      }
    });

    testWidgets('«назад» возвращается в меню паузы', (tester) async {
      var back = 0;
      await pumpView(tester, RulesView(roster: rosterOf(cards), onBack: () => back++));
      await tester.tap(find.bySemanticsLabel('Назад'));
      expect(back, 1);
    });

    testWidgets('все слова справочника умещаются на узком экране без переполнения', (tester) async {
      await pumpView(
        tester,
        RulesView(roster: rosterOf(cards), onBack: () {}),
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
      await tester.dragUntilVisible(
        find.text('Скеллиге'),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
