import 'package:flutter/material.dart' hide Intent, Row;
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/hand_order.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match/presentation/start/first_player_view.dart';
import 'package:gwent/src/features/match/presentation/start/handover_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_intro_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_toss_view.dart';
import 'package:gwent/src/features/match/presentation/start/redraw_view.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../../support/fonts.dart';
import '../../../../support/localized_app.dart';
import '../../../../support/match_fixtures.dart';
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

  Future<void> pumpView(WidgetTester tester, Widget view, {bool reduceMotion = false}) async {
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(view));
  }

  group('знакомство', () {
    testWidgets('в сетевой партии соперника зовут по имени, пустое имя заменяет «Противник»', (tester) async {
      await pumpView(
        tester,
        MatchIntroView(
          roster: rosterOf(cards, opponentName: ' Геральт '),
          onFinished: () {},
        ),
      );
      expect(find.text('Геральт'), findsOneWidget);
      expect(find.text('Противник'), findsNothing);
      await tester.pump(MatchIntroView.duration);
      await pumpView(
        tester,
        MatchIntroView(
          roster: rosterOf(cards, opponentName: '  '),
          onFinished: () {},
        ),
      );
      expect(find.text('Противник'), findsOneWidget);
      await tester.pump(MatchIntroView.duration);
    });

    testWidgets('соперник сверху, «ПРОТИВ» посередине, я снизу; у каждого фракция и колода', (tester) async {
      final roster = rosterOf(
        cards,
        factions: const {Seat.one: Faction.skellige, Seat.two: Faction.monsters},
      );
      await pumpView(tester, MatchIntroView(roster: roster, onFinished: () {}));

      expect(find.text('ПРОТИВ'), findsOneWidget);
      expect(find.text('Вы'), findsOneWidget);
      expect(find.text('Противник'), findsOneWidget);
      expect(find.text('Скеллиге'), findsOneWidget);
      expect(find.text('Чудовища'), findsOneWidget);
      expect(find.textContaining('«Колода 1»', findRichText: true), findsOneWidget);
      expect(find.textContaining('«Колода 2»', findRichText: true), findsOneWidget);
      expect(find.byType(GwentCard), findsNWidgets(2));
      final opponent = tester.getTopLeft(find.text('Противник'));
      final me = tester.getTopLeft(find.text('Вы'));
      expect(opponent.dy, lessThan(me.dy));
      await tester.pump(MatchIntroView.duration);
    });

    testWidgets('в hot-seat игроки называются по номеру, первый внизу', (tester) async {
      await pumpView(tester, MatchIntroView(roster: rosterOf(cards, hotSeat: true), onFinished: () {}));
      expect(find.text('Игрок 1'), findsOneWidget);
      expect(find.text('Игрок 2'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Игрок 2')).dy,
        lessThan(tester.getTopLeft(find.text('Игрок 1')).dy),
      );
      await tester.pump(MatchIntroView.duration);
    });

    testWidgets('безымянная колода (чужая по сети) в знакомстве не называется', (tester) async {
      final roster = rosterOf(cards);
      final nameless = MatchRoster(
        mode: roster.mode,
        content: roster.content,
        localSeats: roster.localSeats,
        players: {
          Seat.one: roster.player(Seat.one),
          Seat.two: MatchPlayer(
            seat: Seat.two,
            faction: roster.player(Seat.two).faction,
            leader: roster.player(Seat.two).leader,
          ),
        },
      );
      await pumpView(tester, MatchIntroView(roster: nameless, onFinished: () {}));
      expect(find.textContaining('«Колода 1»', findRichText: true), findsOneWidget);
      expect(find.textContaining('«Колода 2»', findRichText: true), findsNothing);
      await tester.pump(MatchIntroView.duration);
    });

    testWidgets('по истечении времени знакомство заканчивается один раз', (tester) async {
      var finished = 0;
      await pumpView(tester, MatchIntroView(roster: rosterOf(cards), onFinished: () => finished++));
      await tester.pump(MatchIntroView.duration - const Duration(milliseconds: 100));
      expect(finished, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(finished, 1);
      await tester.tap(find.byType(MatchIntroView));
      await tester.pump(const Duration(seconds: 1));
      expect(finished, 1, reason: 'нажатие после конца ничего не повторяет');
    });

    testWidgets('нажатие пропускает знакомство, повторные нажатия и таймер его не повторяют', (tester) async {
      var finished = 0;
      await pumpView(tester, MatchIntroView(roster: rosterOf(cards), onFinished: () => finished++));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byType(MatchIntroView));
      await tester.tap(find.byType(MatchIntroView));
      await tester.pump(MatchIntroView.duration);
      expect(finished, 1);
    });

    testWidgets('при «уменьшить движение» знакомство тоже заканчивается по времени', (tester) async {
      var finished = 0;
      await pumpView(
        tester,
        MatchIntroView(roster: rosterOf(cards), onFinished: () => finished++),
        reduceMotion: true,
      );
      await tester.pump(MatchIntroView.duration + const Duration(milliseconds: 100));
      expect(finished, 1);
    });
  });

  group('жребий', () {
    Future<void> pumpToss(
      WidgetTester tester, {
      required Seat first,
      required bool byChoice,
      bool hotSeat = false,
      Map<Seat, Faction> factions = const {Seat.one: Faction.skellige, Seat.two: Faction.monsters},
      VoidCallback? onFinished,
    }) => pumpView(
      tester,
      MatchTossView(
        roster: rosterOf(cards, hotSeat: hotSeat, factions: factions),
        first: first,
        byChoice: byChoice,
        onFinished: onFinished ?? () {},
      ),
    );

    testWidgets('я выиграл жребий: пока монета летит — «Бросаем монету…», потом результат', (tester) async {
      await pumpToss(tester, first: Seat.one, byChoice: false);
      expect(find.text('ЖРЕБИЙ'), findsOneWidget);
      expect(find.text('Бросаем монету…'), findsOneWidget);
      expect(find.text('Вы ходите первым'), findsNothing);

      await tester.pump(MatchTossView.flip + const Duration(milliseconds: 700));
      expect(find.text('Бросаем монету…'), findsNothing);
      expect(find.text('Вы ходите первым'), findsOneWidget);
      expect(find.text('Решил жребий'), findsOneWidget);
      await tester.pump(MatchTossView.hold);
    });

    testWidgets('первым ходит противник', (tester) async {
      await pumpToss(tester, first: Seat.two, byChoice: false);
      await tester.pump(MatchTossView.flip + const Duration(milliseconds: 700));
      expect(find.text('Первым ходит противник'), findsOneWidget);
      await tester.pump(MatchTossView.hold);
    });

    testWidgets('в hot-seat называется игрок по номеру', (tester) async {
      await pumpToss(tester, first: Seat.two, byChoice: false, hotSeat: true);
      await tester.pump(MatchTossView.flip + const Duration(milliseconds: 700));
      expect(find.text('Первым ходит Игрок 2'), findsOneWidget);
      await tester.pump(MatchTossView.hold);
    });

    testWidgets("оба Скоя'таэли: жребий и пометка об этом", (tester) async {
      await pumpToss(
        tester,
        first: Seat.one,
        byChoice: false,
        factions: const {Seat.one: Faction.scoiatael, Seat.two: Faction.scoiatael},
      );
      await tester.pump(MatchTossView.flip + const Duration(milliseconds: 700));
      expect(find.text("Оба игрока — Скоя'таэли, решил жребий"), findsOneWidget);
      await tester.pump(MatchTossView.hold);
    });

    testWidgets("выбор Скоя'таэлей: заголовок «Выбор», монеты нет, решение Скоя'таэлей", (tester) async {
      await pumpToss(
        tester,
        first: Seat.two,
        byChoice: true,
        factions: const {Seat.one: Faction.skellige, Seat.two: Faction.scoiatael},
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ВЫБОР'), findsOneWidget);
      expect(find.text('Бросаем монету…'), findsNothing);
      expect(find.text("Решение Скоя'таэлей"), findsOneWidget);
      expect(find.text('Первым ходит противник'), findsOneWidget);
      await tester.pump(MatchTossView.hold + MatchTossView.flip);
    });

    testWidgets('результат держится, потом экран заканчивается один раз', (tester) async {
      var finished = 0;
      await pumpToss(tester, first: Seat.one, byChoice: false, onFinished: () => finished++);
      await tester.pump(MatchTossView.flip + const Duration(milliseconds: 700));
      expect(finished, 0);
      await tester.pump(MatchTossView.hold);
      expect(finished, 1);
      await tester.tap(find.byType(MatchTossView));
      await tester.pump(const Duration(seconds: 1));
      expect(finished, 1);
    });

    testWidgets('нажатие заканчивает экран сразу', (tester) async {
      var finished = 0;
      await pumpToss(tester, first: Seat.one, byChoice: false, onFinished: () => finished++);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(MatchTossView));
      expect(finished, 1);
      await tester.pump(MatchTossView.flip + MatchTossView.hold);
      expect(finished, 1);
    });
  });

  group('выбор первого игрока', () {
    final options = [const SeatOption(Seat.one), const SeatOption(Seat.two)];

    testWidgets('кнопки «Я» и «Противник», ответ уходит движку', (tester) async {
      final intents = <Intent>[];
      final view = viewOf(
        cards,
        phase: MatchPhase.choosingFirstPlayer,
        choice: PendingChoice(seat: Seat.one, kind: ChoiceKind.firstPlayer, options: options),
      );
      await pumpView(tester, MatchFirstPlayerView(view: view, roster: rosterOf(cards), onIntent: intents.add));
      expect(find.text('Кто ходит первым?'), findsOneWidget);
      expect(find.text("СКОЯ'ТАЭЛИ"), findsOneWidget);
      await tester.tap(find.text('Противник'));
      await tester.tap(find.text('Я'));
      expect(intents, [const ChooseOption(SeatOption(Seat.two)), const ChooseOption(SeatOption(Seat.one))]);
    });

    testWidgets('в hot-seat назван игрок, которому решать', (tester) async {
      final view = viewOf(
        cards,
        phase: MatchPhase.choosingFirstPlayer,
        choice: PendingChoice(seat: Seat.one, kind: ChoiceKind.firstPlayer, options: options),
      );
      await pumpView(
        tester,
        MatchFirstPlayerView(view: view, roster: rosterOf(cards, hotSeat: true), onIntent: (_) {}),
      );
      expect(find.textContaining('Игрок 1'), findsWidgets);
    });

    testWidgets('решает соперник: ожидание без кнопок', (tester) async {
      await pumpView(
        tester,
        MatchFirstPlayerView(
          view: viewOf(cards, phase: MatchPhase.choosingFirstPlayer, turn: null),
          roster: rosterOf(cards),
          onIntent: (_) {},
        ),
      );
      expect(find.text('Противник решает'), findsOneWidget);
      expect(find.text('Ожидание выбора…'), findsOneWidget);
      expect(find.text('Я'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('пересдача', () {
    List<CardInstance> hand() => [cards.unit(Row.melee), cards.unit(Row.ranged)];

    testWidgets('нажатие на карту меняет её, «Готово» заканчивает пересдачу', (tester) async {
      final intents = <Intent>[];
      final cardsInHand = hand();
      final view = viewOf(
        cards,
        phase: MatchPhase.redraw,
        me: sideOf(cards, Seat.one, hand: cardsInHand, redrawsLeft: 2),
      );
      await pumpView(tester, MatchRedrawView(view: view, roster: rosterOf(cards), onIntent: intents.add));
      expect(find.text('Пересдача'), findsOneWidget);
      expect(find.text('Можно заменить: 2'), findsOneWidget);
      await tester.tap(find.byType(GwentCard).first);
      expect(intents, [RedrawCard(HandOrder(content).sort(cardsInHand).first.id)], reason: 'первая на экране');
      await tester.tap(find.text('Готово'));
      expect(intents.last, const FinishRedraw());
    });

    testWidgets('замена: старая карта сворачивается, затем новая проявляется на своём месте и светится', (
      tester,
    ) async {
      final first = hand();
      final arrived = cards.unit(Row.siege);
      final before = viewOf(
        cards,
        phase: MatchPhase.redraw,
        me: sideOf(cards, Seat.one, hand: first, redrawsLeft: 2),
      );
      final after = viewOf(
        cards,
        phase: MatchPhase.redraw,
        me: sideOf(cards, Seat.one, hand: [arrived, first[1]], redrawsLeft: 1),
      );
      await pumpView(tester, MatchRedrawView(view: before, roster: rosterOf(cards), onIntent: (_) {}));
      expect(find.byType(GwentCard), findsNWidgets(2));
      expect(_justPlayed(tester), isEmpty, reason: 'пока ничего не заменяли, свечения нет');

      await tester.pumpWidget(
        localizedApp(MatchRedrawView(view: after, roster: rosterOf(cards), onIntent: (_) {})),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(GwentCard), findsNWidgets(2), reason: 'посреди замены уходящая карта ещё на своём месте');
      expect(_shown(tester), contains(first[0].id));
      expect(_justPlayed(tester), isEmpty, reason: 'новая карта проявится после того, как старая свернётся');

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GwentCard), findsNWidgets(2), reason: 'после замены остаётся новая карта');
      expect(_shown(tester), isNot(contains(first[0].id)));
      expect(_justPlayed(tester), hasLength(1), reason: 'пока карту не заметили, она светится');
      await tester.pump(const Duration(milliseconds: 1500));
      expect(_justPlayed(tester), isEmpty, reason: 'свечение гаснет, когда карту заметили');
    });

    testWidgets('пересборка с той же рукой посреди замены не затягивает сворачивание, нажатия на ходу не идут', (
      tester,
    ) async {
      final intents = <Intent>[];
      final first = hand();
      MatchRedrawView viewWith(List<CardInstance> shown, int left) => MatchRedrawView(
        view: viewOf(
          cards,
          phase: MatchPhase.redraw,
          me: sideOf(cards, Seat.one, hand: shown, redrawsLeft: left),
        ),
        roster: rosterOf(cards),
        onIntent: intents.add,
      );
      final replaced = [cards.unit(Row.siege), first[1]];
      await pumpView(tester, viewWith(first, 2));
      await tester.pumpWidget(localizedApp(viewWith(replaced, 1)));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byType(GwentCard).first, warnIfMissed: false);
      expect(intents, isEmpty, reason: 'пока старая карта сворачивается, нажатия не принимаются');

      await tester.pumpWidget(localizedApp(viewWith(replaced, 1)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_shown(tester), isNot(contains(first[0].id)), reason: 'сворачивание кончилось в срок');
      expect(_justPlayed(tester), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('рука идёт в порядке руки, а пришедшая карта встаёт на отсортированное место', (tester) async {
      final order = HandOrder(content);
      final inHand = [cards.hero(), cards.unit(Row.melee), cards.unit(Row.ranged), cards.unit(Row.siege)];
      final arrived = cards.unit(Row.melee);
      MatchRedrawView viewWith(List<CardInstance> shown, int left) => MatchRedrawView(
        view: viewOf(
          cards,
          phase: MatchPhase.redraw,
          me: sideOf(cards, Seat.one, hand: shown, redrawsLeft: left),
        ),
        roster: rosterOf(cards),
        onIntent: (_) {},
      );

      await pumpView(tester, viewWith(inHand, 2));
      expect(_shown(tester), [for (final card in order.sort(inHand)) card.id]);

      final replaced = [...inHand]..[0] = arrived;
      await tester.pumpWidget(localizedApp(viewWith(replaced, 1)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(_shown(tester), [for (final card in order.sort(replaced)) card.id]);
      expect(_justPlayed(tester), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('«Уменьшить движение»: карта заменяется сразу, без сворачивания', (tester) async {
      final first = hand();
      final before = viewOf(
        cards,
        phase: MatchPhase.redraw,
        me: sideOf(cards, Seat.one, hand: first, redrawsLeft: 2),
      );
      final after = viewOf(
        cards,
        phase: MatchPhase.redraw,
        me: sideOf(cards, Seat.one, hand: [cards.unit(Row.siege), first[1]], redrawsLeft: 1),
      );
      await pumpView(
        tester,
        MatchRedrawView(view: before, roster: rosterOf(cards), onIntent: (_) {}),
        reduceMotion: true,
      );
      await tester.pumpWidget(
        localizedApp(MatchRedrawView(view: after, roster: rosterOf(cards), onIntent: (_) {})),
      );
      await tester.pump();
      expect(find.byType(GwentCard), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('после последней замены (settled) карты и «Готово» недоступны, пришедшая карта светится', (
      tester,
    ) async {
      final intents = <Intent>[];
      final first = hand();
      final before = viewOf(
        cards,
        phase: MatchPhase.redraw,
        me: sideOf(cards, Seat.one, hand: first, redrawsLeft: 1),
      );
      final after = viewOf(
        cards,
        phase: MatchPhase.redraw,
        me: sideOf(cards, Seat.one, hand: [cards.unit(Row.siege), first[1]], redrawsLeft: 0),
      );
      await pumpView(tester, MatchRedrawView(view: before, roster: rosterOf(cards), onIntent: intents.add));
      await tester.pumpWidget(
        localizedApp(MatchRedrawView(view: after, roster: rosterOf(cards), onIntent: intents.add, settled: true)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Можно заменить: 0'), findsOneWidget);
      expect(_justPlayed(tester), hasLength(1));
      await tester.tap(find.byType(GwentCard).first, warnIfMissed: false);
      await tester.tap(find.text('Готово'), warnIfMissed: false);
      expect(intents, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('две замены подряд: светятся обе пришедшие карты', (tester) async {
      final first = hand();
      MatchRedrawView viewOf2(List<CardInstance> inHand, int left) => MatchRedrawView(
        view: viewOf(
          cards,
          phase: MatchPhase.redraw,
          me: sideOf(cards, Seat.one, hand: inHand, redrawsLeft: left),
        ),
        roster: rosterOf(cards),
        onIntent: (_) {},
      );
      final firstArrived = cards.unit(Row.siege);
      final secondArrived = cards.unit(Row.melee);
      await pumpView(tester, viewOf2(first, 2));
      await tester.pumpWidget(localizedApp(viewOf2([firstArrived, first[1]], 1)));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(localizedApp(viewOf2([firstArrived, secondArrived], 0)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_justPlayed(tester), hasLength(2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('неполный последний ряд занимает места колонок: 11-я карта не прижата к 10-й', (tester) async {
      final view = viewOf(
        cards,
        phase: MatchPhase.redraw,
        me: sideOf(cards, Seat.one, hand: [for (var i = 0; i < 11; i++) cards.unit(Row.melee)], redrawsLeft: 2),
      );
      await pumpView(tester, MatchRedrawView(view: view, roster: rosterOf(cards), onIntent: (_) {}));
      final lefts = [
        for (final card in tester.widgetList(find.byType(GwentCard))) tester.getTopLeft(find.byWidget(card)).dx,
      ];
      expect(lefts, hasLength(11));
      expect(lefts[9], lefts[0], reason: '10-я карта стоит в первой колонке');
      expect(lefts[10], lefts[1], reason: '11-я карта стоит во второй колонке, а не рядом с 10-й');
    });

    testWidgets('замены кончились: карты неактивны, надпись «Можно заменить: 0»', (tester) async {
      final intents = <Intent>[];
      final view = viewOf(
        cards,
        phase: MatchPhase.redraw,
        me: sideOf(cards, Seat.one, hand: hand(), redrawsLeft: 0),
      );
      await pumpView(tester, MatchRedrawView(view: view, roster: rosterOf(cards), onIntent: intents.add));
      expect(find.text('Можно заменить: 0'), findsOneWidget);
      await tester.tap(find.byType(GwentCard).first, warnIfMissed: false);
      expect(intents, isEmpty);
    });

    testWidgets('в hot-seat над заголовком имя игрока и фракция', (tester) async {
      final view = viewOf(
        cards,
        phase: MatchPhase.redraw,
        me: sideOf(cards, Seat.one, hand: hand(), redrawsLeft: 2),
      );
      await pumpView(
        tester,
        MatchRedrawView(view: view, roster: rosterOf(cards, hotSeat: true), onIntent: (_) {}),
      );
      expect(find.text('ИГРОК 1 · СКЕЛЛИГЕ'), findsOneWidget);
    });

    testWidgets('ожидание соперника: сколько карт я заменил', (tester) async {
      final view = viewOf(
        cards,
        phase: MatchPhase.redraw,
        me: sideOf(cards, Seat.one, hand: hand(), redrawsLeft: 0, redrawDone: true),
      );
      await pumpView(tester, MatchRedrawWaitView(view: view, roster: rosterOf(cards)));
      expect(find.text('Противник меняет карты…'), findsOneWidget);
      expect(find.text('Вы заменили карт: 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('передача телефона', () {
    Future<void> pumpHandover(WidgetTester tester, HandoverKind kind, {VoidCallback? onReady}) => pumpView(
      tester,
      MatchHandoverView(
        next: Seat.two,
        kind: kind,
        roster: rosterOf(cards, hotSeat: true),
        onReady: onReady ?? () {},
      ),
    );

    for (final (kind, text) in [
      (
        HandoverKind.firstPlayerChoice,
        'Сейчас решается, кто ходит первым. Рука скрыта: нажмите «Я готов», когда телефон у вас.',
      ),
      (HandoverKind.redraw, 'Сейчас — пересдача карт. Рука скрыта: нажмите «Я готов», когда телефон у вас.'),
      (HandoverKind.firstMove, 'Рука скрыта. Первым ходит Игрок 2. Нажмите «Я готов», когда телефон у вас.'),
      (
        HandoverKind.turn,
        'Рука скрыта. Нажмите «Я готов», когда телефон у вас: Игрок 2 увидит свои карты и поле.',
      ),
    ]) {
      testWidgets('подпись для вида «${kind.name}»', (tester) async {
        await pumpHandover(tester, kind);
        expect(find.text('Передайте телефон:'), findsOneWidget);
        expect(find.text('Игрок 2'), findsWidgets);
        expect(find.text(text), findsOneWidget);
        expect(
          tester.widgetList<GwentCard>(find.byType(GwentCard)).map((card) => card.face),
          everyElement(isA<CardBackFace>()),
          reason: 'руку до подтверждения не показываем: на экране только рубашки',
        );
      });
    }

    testWidgets('«Я готов» подтверждает передачу', (tester) async {
      var ready = 0;
      await pumpHandover(tester, HandoverKind.turn, onReady: () => ready++);
      await tester.tap(find.text('Я готов'));
      expect(ready, 1);
    });
  });
}

/// Карты руки со свечением «только что пришла».
Iterable<GwentCard> _justPlayed(WidgetTester tester) =>
    tester.widgetList<GwentCard>(find.byType(GwentCard)).where((card) => card.highlight == CardHighlight.justPlayed);

/// Номера карт на экране пересдачи слева направо, сверху вниз.
List<Object?> _shown(WidgetTester tester) => [
  for (final card in tester.widgetList<GwentCard>(find.byType(GwentCard)))
    (card.key! as ValueKey<CardInstanceId>).value,
];
