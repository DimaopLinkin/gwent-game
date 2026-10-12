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
    cubit = FieldCubit();
    addTearDown(cubit.close);
  });

  MatchInProgress progress(PlayerView view, {List<GameEvent> events = const [], Reject? refusal}) =>
      MatchInProgress(view: view, content: content, events: events, refusal: refusal);

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

  test('пас соперника показывает баннер, свой пас нет; баннер убирается', () {
    final view = viewOf(cards);
    cubit.onMatchState(progress(view, events: const [Passed(Seat.one, auto: false)]));
    expect(cubit.state.showOpponentPassed, isFalse);
    cubit.onMatchState(progress(view, events: const [Passed(Seat.two, auto: false)]));
    expect(cubit.state.showOpponentPassed, isTrue);
    cubit.clearBanner();
    expect(cubit.state.showOpponentPassed, isFalse);
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
    cubit.onMatchState(const MatchHandover(Seat.two));
    expect(cubit.state.selected, isNull);
    expect(cubit.state.overlay, isA<NoOverlay>());
  });
}
