import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/match_builder.dart';

/// Раздел 4 сетевой спецификации: скрытая информация не попадает к сопернику.
void main() {
  test('проекция: своя рука открыта, у соперника только количество карт руки и колоды', () {
    final state = playing(
      one: const Side(hand: ['footman', 'archer'], deck: ['catapult'], discard: ['ghoul']),
      two: const Side(hand: ['vesemir'], deck: ['geralt', 'footman']),
    );
    final view = engine.project(state, Seat.one);
    expect(names(view.me.hand!), ['footman', 'archer']);
    expect(view.me.deckCount, 1);
    expect(view.opponent.hand, isNull);
    expect(view.opponent.handCount, 1);
    expect(view.opponent.deckCount, 2);
    expect(names(view.me.discard), ['ghoul']);
  });

  test('выбор соперника виден только как его вид', () {
    final state = playing(
      one: const Side(hand: ['banner_medic'], discard: ['footman']),
      two: const Side(hand: ['archer']),
    );
    final result = act(engine, state, Seat.one, PlayCard(find(state, Seat.one, 'banner_medic')));
    expect(engine.project(result.state, Seat.one).choice?.kind, ChoiceKind.medicTarget);
    expect(engine.project(result.state, Seat.two).choice, isNull);
    expect(engine.project(result.state, Seat.two).opponentChoosing, ChoiceKind.medicTarget);
    expect(
      engine.eventsFor(result.events, Seat.two).whereType<ChoiceRequested>().single,
      const ChoiceRequested(Seat.one, ChoiceKind.medicTarget, []),
    );
  });

  test('выбор из колоды отрисовывается по одной проекции и событиям выбирающего', () {
    final state = playing(
      one: const Side(leader: 'eredin_weather', faction: Faction.monsters, deck: ['footman', 'rain', 'clear']),
      two: const Side(hand: ['archer']),
    );
    final result = act(engine, state, Seat.one, const UseLeader());
    List<String> shown(List<ChoiceOption> options) => [
      for (final option in options)
        if (option case CardOption(:final card)) card.cardId.value,
    ];
    expect(shown(engine.project(result.state, Seat.one).choice!.options), ['rain', 'clear']);
    expect(shown(engine.eventsFor(result.events, Seat.one).whereType<ChoiceRequested>().single.options), [
      'rain',
      'clear',
    ]);
    expect(engine.eventsFor(result.events, Seat.two).whereType<ChoiceRequested>().single.options, isEmpty);
  });

  test('взятые карты сопернику видны только числом', () {
    final events = [
      const CardsDrawn(Seat.one, [CardInstance(CardInstanceId(5), CardId('footman'))]),
    ];
    expect(engine.eventsFor(events, Seat.one), events);
    expect(engine.eventsFor(events, Seat.two), [const CardsDrawnHidden(Seat.one, 1)]);
  });
}
