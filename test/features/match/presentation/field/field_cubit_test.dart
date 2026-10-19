import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../../support/match_fixtures.dart';
import 'field_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late TestCards cards;
  late FieldCubit cubit;

  setUpAll(() async => content = await loadBaseContent());
  setUp(() {
    cards = TestCards(content);
    cubit = FieldCubit(finishHold: const Duration(milliseconds: 30));
    addTearDown(cubit.close);
  });

  MatchInProgress progress(
    PlayerView view, {
    List<GameEvent> events = const [],
    Reject? refusal,
    PlayerView? closing,
  }) => MatchInProgress(
    view: view,
    content: content,
    roster: rosterOf(cards),
    events: events,
    refusal: refusal,
    closing: closing,
  );

  group('занятость поля', () {
    test('поле свободно, пока нет баннеров, итога раунда, паузы и конца партии', () {
      expect(cubit.state.isBusy, isFalse);
      cubit.onMatchState(progress(viewOf(cards), events: const [TurnStarted(Seat.one)]));
      expect(cubit.state.isBusy, isTrue, reason: 'идёт баннер хода');
      cubit.dismissBanner();
      expect(cubit.state.isBusy, isFalse);
      cubit.openPause();
      expect(cubit.state.isBusy, isTrue, reason: 'пауза держит следующие состояния партии');
      cubit.closePause();
      expect(cubit.state.isBusy, isFalse);
    });

    test('итог раунда держит поле занятым, пока игрок его не закроет', () {
      const result = RoundResult(round: 1, scores: {Seat.one: 17, Seat.two: 9}, winner: Seat.one);
      cubit.onMatchState(progress(viewOf(cards), events: const [RoundEnded(result)]));
      expect(cubit.state.summary, isNotNull);
      expect(cubit.state.isBusy, isTrue);
      cubit.dismissSummary();
      expect(cubit.state.isBusy, isFalse);
    });

    test('конец партии по кристаллам: поле держит последний ход, затем отпускает', () async {
      const result = RoundResult(round: 3, scores: {Seat.one: 17, Seat.two: 9}, winner: Seat.one);
      cubit.onMatchState(
        progress(
          viewOf(cards, phase: MatchPhase.finished, turn: null),
          events: const [
            RoundEnded(result),
            MatchEnded(MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals)),
          ],
        ),
      );
      expect(cubit.state.finishing, isTrue);
      expect(cubit.state.isBusy, isTrue);
      cubit.openPause();
      expect(cubit.state.pause, PauseLayer.none, reason: 'пока поле держит конец партии, пауза не нужна');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cubit.state.finishing, isFalse);
      expect(cubit.state.isBusy, isFalse);
    });

    test('сдача поле не держит: итог матча открывается сразу', () {
      cubit.onMatchState(
        progress(
          viewOf(cards, phase: MatchPhase.finished, turn: null),
          events: const [MatchEnded(MatchOutcome(winner: Seat.two, reason: MatchEndReason.resignation))],
        ),
      );
      expect(cubit.state.finishing, isFalse);
    });

    test('итог матча или передача телефона сбрасывают удержание конца партии', () {
      cubit.onMatchState(
        progress(
          viewOf(cards, phase: MatchPhase.finished, turn: null),
          events: const [MatchEnded(MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals))],
        ),
      );
      expect(cubit.state.finishing, isTrue);
      cubit.onMatchState(
        MatchFinished(
          view: viewOf(cards, phase: MatchPhase.finished, turn: null),
          roster: rosterOf(cards),
          events: const [],
        ),
      );
      expect(cubit.state.finishing, isFalse);
      expect(cubit.state.isClean, isTrue);
    });
  });

  group('конец раунда со сценарием', () {
    const result = RoundResult(round: 1, scores: {Seat.one: 5, Seat.two: 2}, winner: Seat.one);

    PlayerView closingBoard() {
      final unit = cards.unit(Row.melee);
      return viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          rows: {
            Row.melee: rowOf([unit], cards),
          },
          score: 5,
        ),
      );
    }

    test('поле раунда даёт сценарий вместо листа итога, и поле занято, пока он идёт', () {
      final after = viewOf(cards, round: 2, turn: Seat.two);
      cubit.onMatchState(
        progress(
          after,
          closing: closingBoard(),
          events: const [
            Passed(Seat.one, auto: false),
            RoundEnded(result),
            RoundStarted(2, Seat.two),
            TurnStarted(Seat.two),
          ],
        ),
      );
      expect(cubit.state.stage, isNotNull);
      expect(cubit.state.summary, isNull, reason: 'итог показывает плашка сценария');
      expect(cubit.state.isBusy, isTrue);
      cubit.endStage(cubit.state.stage!.id);
      expect(cubit.state.isBusy, isTrue, reason: 'баннер нового раунда ещё впереди');
    });

    test('без поля раунда остаётся лист итога', () {
      cubit.onMatchState(
        progress(viewOf(cards, round: 2), events: const [RoundEnded(result), RoundStarted(2, Seat.two)]),
      );
      expect(cubit.state.stage, isNull);
      expect(cubit.state.summary, isNotNull);
    });

    test('один раунд показывается один раз', () {
      const events = [RoundEnded(result), RoundStarted(2, Seat.two)];
      final after = viewOf(cards, round: 2);
      cubit.onMatchState(progress(after, closing: closingBoard(), events: events));
      cubit.endStage(cubit.state.stage!.id);
      cubit.onMatchState(progress(after, closing: closingBoard(), events: events));
      expect(cubit.state.stage, isNull);
    });

    test('конец партии по камням: сценарий сам держит поле, отдельное удержание не нужно', () {
      cubit.onMatchState(
        progress(
          viewOf(cards, phase: MatchPhase.finished, turn: null),
          closing: closingBoard(),
          events: const [
            RoundEnded(result),
            MatchEnded(MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals)),
          ],
        ),
      );
      expect(cubit.state.stage, isNotNull);
      expect(cubit.state.finishing, isFalse);
      expect(cubit.state.summary, isNull);
    });
  });

  test('выбор карты переключается повторным нажатием и снимается', () {
    cubit.toggleSelected(const CardInstanceId(1));
    expect(cubit.state.selected, const CardInstanceId(1));
    cubit.toggleSelected(const CardInstanceId(2));
    expect(cubit.state.selected, const CardInstanceId(2));
    cubit.toggleSelected(const CardInstanceId(2));
    expect(cubit.state.selected, isNull);
    cubit
      ..select(const CardInstanceId(3))
      ..clearSelected();
    expect(cubit.state.selected, isNull);
  });

  test('листы сброса и лидера открываются и закрываются, порядок сброса запоминается', () {
    cubit.openDiscard(mine: false);
    expect(cubit.state.overlay, isA<DiscardOverlay>().having((overlay) => overlay.mine, 'mine', isFalse));
    cubit.openLeader(mine: true);
    expect(cubit.state.overlay, isA<LeaderOverlay>().having((overlay) => overlay.mine, 'mine', isTrue));
    cubit.setSort(DiscardSort.byOrder);
    expect(cubit.state.sort, DiscardSort.byOrder);
    cubit.closeOverlay();
    expect(cubit.state.overlay, isA<NoOverlay>());
  });

  test('тосты нумеруются, чужой номер тост не убирает', () {
    cubit.say(FieldMessage.opponentTurn);
    final first = cubit.state.toast!;
    cubit.say(FieldMessage.opponentTurn);
    final second = cubit.state.toast!;
    expect(second.id, isNot(first.id));
    cubit.clearToast(first.id);
    expect(cubit.state.toast, second);
    cubit.clearToast(second.id);
    expect(cubit.state.toast, isNull);
  });

  test('выбор карты сбрасывается, когда карта перестала быть доступной', () {
    final unit = cards.unit(Row.melee);
    cubit.select(unit.id);
    cubit.onMatchState(progress(viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit]))));
    expect(cubit.state.selected, unit.id, reason: 'карта на руке и играется');
    cubit.onMatchState(
      progress(
        viewOf(
          cards,
          me: sideOf(cards, Seat.one, hand: [unit], playable: const {}),
        ),
      ),
    );
    expect(cubit.state.selected, isNull);
  });

  test('рука соперника, показанная лидером, открывается листом, чужой показ нет', () {
    final shown = [cards.unit(Row.melee), cards.unit(Row.ranged)];
    final view = viewOf(cards);
    cubit.onMatchState(progress(view, events: [HandRevealed(Seat.two, shown)]));
    expect(cubit.state.overlay, isA<NoOverlay>());
    cubit.onMatchState(progress(view, events: [HandRevealed(Seat.one, shown)]));
    expect(cubit.state.overlay, isA<RevealOverlay>().having((overlay) => overlay.cards, 'cards', shown));
  });

  test('пас соперника и свой пас ставят в очередь баннеры, баннер убирается по одному', () {
    final view = viewOf(cards);
    cubit.onMatchState(progress(view, events: const [Passed(Seat.one, auto: false)]));
    expect(cubit.state.banners, hasLength(1));
    expect(cubit.state.banners.single, isA<PassBanner>().having((banner) => banner.mine, 'mine', isTrue));
    cubit.onMatchState(progress(view, events: const [Passed(Seat.two, auto: false)]));
    expect(cubit.state.banners, hasLength(2));
    expect(cubit.state.banners.last, isA<PassBanner>().having((banner) => banner.mine, 'mine', isFalse));
    cubit.dismissBanner();
    expect(cubit.state.banners.single, isA<PassBanner>().having((banner) => banner.mine, 'mine', isFalse));
    cubit
      ..dismissBanner()
      ..dismissBanner();
    expect(cubit.state.banners, isEmpty);
  });

  test('начало раунда объявляется один раз, у обоих кристаллов по одному — «решающий раунд»', () {
    final view = viewOf(
      cards,
      round: 3,
      me: sideOf(cards, Seat.one, crystals: 1),
      opponent: sideOf(cards, Seat.two, crystals: 1),
    );
    const started = RoundStarted(3, Seat.two);
    cubit.onMatchState(progress(view, events: const [started, TurnStarted(Seat.two)]));
    expect(cubit.state.banners.first, isA<RoundStartBanner>().having((banner) => banner.decisive, 'decisive', isTrue));
    expect(cubit.state.banners.first, isA<RoundStartBanner>().having((banner) => banner.round, 'round', 3));
    expect(cubit.state.banners.last, isA<TurnStartBanner>().having((banner) => banner.mine, 'mine', isFalse));
    cubit.onMatchState(progress(view));
    cubit
      ..dismissBanner()
      ..dismissBanner();

    // В hot-seat те же события приходят второму месту, когда телефон перейдёт к нему: раунд не объявляется заново.
    cubit.onMatchState(progress(view, events: const [started]));
    expect(cubit.state.banners, isEmpty);
  });

  test('обычный раунд без решающего: баннер без отметки «решающий»', () {
    cubit.onMatchState(progress(viewOf(cards), events: const [RoundStarted(1, Seat.one)]));
    expect(
      cubit.state.banners.single,
      isA<RoundStartBanner>().having((banner) => banner.decisive, 'decisive', isFalse),
    );
  });

  test('ход объявляется, только когда он перешёл к другому месту', () {
    final view = viewOf(cards);
    cubit.onMatchState(progress(view, events: const [TurnStarted(Seat.one)]));
    expect(cubit.state.banners.single, isA<TurnStartBanner>().having((banner) => banner.mine, 'mine', isTrue));
    cubit.dismissBanner();
    cubit.onMatchState(progress(view, events: const [TurnStarted(Seat.one)]));
    expect(cubit.state.banners, isEmpty, reason: 'после паса соперника каждый мой ход начинается заново');
    cubit.onMatchState(progress(view, events: const [TurnStarted(Seat.two)]));
    expect(cubit.state.banners.single, isA<TurnStartBanner>().having((banner) => banner.mine, 'mine', isFalse));
  });

  test('пас соперника заменяет баннер его хода', () {
    cubit.onMatchState(
      progress(viewOf(cards), events: const [Passed(Seat.two, auto: false), TurnStarted(Seat.one)]),
    );
    expect(cubit.state.banners.map((banner) => banner.runtimeType), [PassBanner]);
  });

  test('пас, которым кончился раунд, баннера не даёт: его объявляет итог раунда', () {
    const result = RoundResult(round: 1, scores: {Seat.one: 10, Seat.two: 4}, winner: Seat.one);
    cubit.onMatchState(
      progress(viewOf(cards), events: [const Passed(Seat.two, auto: false), const RoundEnded(result)]),
    );
    expect(cubit.state.banners, isEmpty);
    expect(cubit.state.summary, isNotNull);
  });

  test('итог раунда: победа, счёт и кристаллы; повтор тех же событий его не показывает заново', () {
    const result = RoundResult(round: 2, scores: {Seat.one: 17, Seat.two: 9}, winner: Seat.one);
    final view = viewOf(
      cards,
      round: 2,
      me: sideOf(cards, Seat.one),
      opponent: sideOf(cards, Seat.two, crystals: 1),
    );
    cubit.onMatchState(progress(view, events: [const RoundEnded(result)]));
    final summary = cubit.state.summary!;
    expect(summary.round, 2);
    expect(summary.outcome, RoundOutcome.win);
    expect((summary.scoreMine, summary.scoreOpponent), (17, 9));
    expect((summary.crystalsMine, summary.crystalsOpponent), (2, 1));
    expect((summary.lostMine, summary.lostOpponent), (false, true));
    expect(summary.marks, isEmpty);

    cubit.dismissSummary();
    expect(cubit.state.summary, isNull);
    cubit.onMatchState(progress(view, events: [const RoundEnded(result)]));
    expect(cubit.state.summary, isNull);
  });

  test('итог раунда глазами второго места: поражение и ничья', () {
    const lost = RoundResult(round: 1, scores: {Seat.one: 17, Seat.two: 9}, winner: Seat.one);
    const tie = RoundResult(round: 2, scores: {Seat.one: 9, Seat.two: 9}, winner: null);
    final view = PlayerView(
      viewer: Seat.two,
      phase: MatchPhase.playing,
      round: 2,
      turn: Seat.two,
      me: sideOf(cards, Seat.two),
      opponent: sideOf(cards, Seat.one),
      weather: const [],
      history: const [],
    );
    cubit.onMatchState(progress(view, events: [const RoundEnded(lost)]));
    expect(cubit.state.summary!.outcome, RoundOutcome.loss);
    expect((cubit.state.summary!.scoreMine, cubit.state.summary!.scoreOpponent), (9, 17));
    cubit.dismissSummary();
    cubit.onMatchState(progress(view, events: [const RoundEnded(tie)]));
    expect(cubit.state.summary!.outcome, RoundOutcome.draw);
    expect((cubit.state.summary!.lostMine, cubit.state.summary!.lostOpponent), (true, true));
  });

  test('итог раунда называет сработавшие способности фракций: карта, оставшийся отряд, победа при ничьей', () {
    const tie = RoundResult(round: 1, scores: {Seat.one: 9, Seat.two: 9}, winner: Seat.one);
    final unit = cards.unit(Row.melee);
    final drawn = cards.unit(Row.ranged);
    cubit.onMatchState(
      progress(
        viewOf(cards),
        events: [
          const RoundEnded(tie),
          UnitKept(Seat.two, Row.melee, unit),
          CardsDrawn(Seat.one, [drawn]),
          const CardsDrawnHidden(Seat.two, 1),
        ],
      ),
    );
    final marks = cubit.state.summary!.marks;
    expect(marks.map((mark) => mark.kind), [
      FactionMarkKind.wonTie,
      FactionMarkKind.unitStays,
      FactionMarkKind.extraCard,
      FactionMarkKind.extraCard,
    ]);
    expect(marks.map((mark) => mark.mine), [true, false, true, false]);
  });

  test('добор после первого хода нового раунда (ход бота в той же пачке) не считается способностью фракции', () {
    const result = RoundResult(round: 1, scores: {Seat.one: 17, Seat.two: 9}, winner: Seat.one);
    final drawn = cards.unit(Row.ranged);
    cubit.onMatchState(
      progress(
        viewOf(cards),
        events: [
          const RoundEnded(result),
          CardsDrawn(Seat.one, [drawn]),
          const TurnStarted(Seat.one),
          const CardsDrawnHidden(Seat.two, 1),
        ],
      ),
    );
    expect(cubit.state.summary!.marks.map((mark) => (mark.kind, mark.mine)), [(FactionMarkKind.extraCard, true)]);
  });

  test('в конце партии итог раунда не нужен: его заменяет итог матча', () {
    const result = RoundResult(round: 2, scores: {Seat.one: 17, Seat.two: 9}, winner: Seat.one);
    cubit.onMatchState(
      progress(
        viewOf(cards),
        events: [
          const RoundEnded(result),
          const MatchEnded(MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals)),
        ],
      ),
    );
    expect(cubit.state.summary, isNull);
  });

  test('слои паузы: меню, правила, сдача и возврат в меню; выбор карты при паузе снимается', () {
    cubit
      ..select(const CardInstanceId(1))
      ..openPause();
    expect(cubit.state.pause, PauseLayer.menu);
    expect(cubit.state.selected, isNull);

    cubit.openRules();
    expect(cubit.state.pause, PauseLayer.rules);
    cubit.backToPauseMenu();
    expect(cubit.state.pause, PauseLayer.menu);

    cubit.askSurrender();
    expect(cubit.state.pause, PauseLayer.surrenderConfirm);
    cubit.backToPauseMenu();
    expect(cubit.state.pause, PauseLayer.menu);

    cubit.closePause();
    expect(cubit.state.pause, PauseLayer.none);
    cubit.backToPauseMenu();
    expect(cubit.state.pause, PauseLayer.none, reason: 'из игры в меню паузы возвращаться некуда');
  });

  test('только что сыгранные карты подсвечиваются до следующих событий', () {
    final unit = cards.unit(Row.melee);
    final created = cards.unit(Row.siege);
    final view = viewOf(cards);
    cubit.onMatchState(
      progress(
        view,
        events: [
          UnitPlaced(Seat.two, Row.melee, unit, EntrySource.hand),
          CreatedCardPlaced(Seat.two, Row.siege, created),
        ],
      ),
    );
    expect(cubit.state.recent, {unit.id, created.id});
    cubit.onMatchState(progress(view, events: const [Passed(Seat.one, auto: false)]));
    expect(cubit.state.recent, isEmpty);
  });

  test('отказ движка показывается красным тостом', () {
    cubit.onMatchState(progress(viewOf(cards), refusal: const Reject(RejectReason.notYourTurn)));
    expect(cubit.state.toast?.message, FieldMessage.refused);
    expect(cubit.state.toast?.isError, isTrue);
  });

  test('телефон ушёл другому игроку или партия закончилась: выбор и листы сброшены', () {
    cubit
      ..select(const CardInstanceId(1))
      ..openLeader(mine: true);
    cubit.onMatchState(MatchHandover(Seat.two, kind: HandoverKind.turn, roster: rosterOf(cards, hotSeat: true)));
    expect(cubit.state.selected, isNull);
    expect(cubit.state.overlay, isA<NoOverlay>());
  });

  test('новая партия забывает, что объявлялось в прошлой: раунд снова объявляется', () {
    cubit.onMatchState(progress(viewOf(cards), events: const [RoundStarted(1, Seat.one)]));
    expect(cubit.state.banners, hasLength(1));
    cubit.onMatchState(MatchIntro(rosterOf(cards)));
    expect(cubit.state.isClean, isTrue);
    cubit.onMatchState(progress(viewOf(cards), events: const [RoundStarted(1, Seat.one)]));
    expect(cubit.state.banners, hasLength(1));
  });

  test('передача телефона сбрасывает и тост, и баннер пасса, и порядок сброса', () {
    cubit
      ..say(FieldMessage.opponentTurn)
      ..setSort(DiscardSort.byOrder);
    cubit.onMatchState(progress(viewOf(cards), events: const [Passed(Seat.two, auto: false)]));
    expect(cubit.state.isClean, isFalse);
    cubit.onMatchState(MatchHandover(Seat.two, kind: HandoverKind.turn, roster: rosterOf(cards, hotSeat: true)));
    expect(cubit.state.toast, isNull);
    expect(cubit.state.banners, isEmpty);
    expect(cubit.state.sort, DiscardSort.byStrength);
    expect(cubit.state.isClean, isTrue);
  });
}
