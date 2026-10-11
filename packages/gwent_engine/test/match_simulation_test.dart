import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_engine/src/state/effect.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Полные партии простым ботом: детерминизм по сиду, сохранение карт и скрытая информация.
void main() {
  Deck deck(String leader, List<String> cards) =>
      Deck(leader: LeaderId(leader), cards: [for (final card in cards) CardId(card)]);

  final skellige = deck('crach', [
    'berserk',
    'young_berserk',
    'young_berserk',
    'mysovur',
    'cerys',
    'drummond',
    'drummond',
    'kambi',
    'pirate',
    'olaf',
    'udalryk',
    'mardrem',
    'cow',
    'dandelion',
    'footman',
    'archer',
    'frost',
    'storm',
    'clear',
    'decoy',
    'scorch',
    'horn',
  ]);
  final nilfgaard = deck('emgyr_take', [
    'skellen',
    'mysterious_elf',
    'archer_medic',
    'archer_medic',
    'villentretenmerth',
    'yennefer',
    'vesemir',
    'geralt',
    'dandelion',
    'footman',
    'footman',
    'archer',
    'archer',
    'fog',
    'rain',
    'decoy',
    'horn',
    'scorch',
    'clear',
  ]);
  final monsters = deck('eredin_oberon', [
    'arachas',
    'arachas',
    'arachas',
    'behemoth',
    'kejran',
    'harpy',
    'ghoul',
    'ghoul',
    'ghoul',
    'villentretenmerth',
    'yennefer',
    'vesemir',
    'geralt',
    'cow',
    'fog',
    'rain',
    'decoy',
    'horn',
    'scorch',
  ]);
  final northern = deck('foltest_siege_scorch', [
    'blue_stripes',
    'blue_stripes',
    'blue_stripes',
    'kaedwen_siege',
    'kaedwen_siege',
    'kaedwen_siege',
    'thaler',
    'banner_medic',
    'catapult',
    'catapult',
    'poor_infantry',
    'poor_infantry',
    'dandelion',
    'footman',
    'archer',
    'frost',
    'horn',
    'decoy',
    'scorch',
  ]);
  final scoiatael = deck('francesca_agile', [
    'elf_skirmisher',
    'elf_skirmisher',
    'elf_skirmisher',
    'schirru',
    'vesemir',
    'geralt',
    'yennefer',
    'footman',
    'footman',
    'archer',
    'archer',
    'cow',
    'frost',
    'fog',
    'decoy',
    'horn',
  ]);
  final pairings = [(skellige, nilfgaard), (monsters, northern), (scoiatael, skellige), (northern, scoiatael)];

  /// Кто сейчас должен действовать.
  Seat actor(MatchState state) =>
      state.choice?.seat ??
      (state.phase == MatchPhase.redraw
          ? Seat.values.firstWhere((seat) => !state.player(seat).redrawDone)
          : state.turn!);

  /// Детерминированный простой бот: перебирает намерения, пока движок не примет одно.
  Accepted step(GwentEngine engine, MatchState state, int turn) {
    final seat = actor(state);
    final candidates = <Intent>[];
    final choice = state.choice;
    if (choice != null) {
      candidates.add(ChooseOption(choice.options[turn % choice.options.length]));
    } else if (state.phase == MatchPhase.redraw) {
      final hand = state.player(seat).hand;
      if (turn.isEven) candidates.add(RedrawCard(hand[turn % hand.length].id));
      candidates.add(const FinishRedraw());
    } else {
      final player = state.player(seat);
      if (turn % 7 == 0) candidates.add(const UseLeader());
      final hand = player.hand;
      final own = [for (final row in player.rows.values) ...row.cards.map((card) => card.card.id)];
      for (var i = 0; i < hand.length; i++) {
        final card = hand[(i + turn) % hand.length].id;
        for (final row in [null, ...Row.values]) {
          candidates.add(PlayCard(card, row: row));
          for (final target in own) {
            candidates.add(PlayCard(card, row: row, target: target));
          }
        }
      }
      candidates.add(const Pass());
    }
    for (final intent in candidates) {
      if (engine.apply(state, seat, intent) case final Accepted accepted) return accepted;
    }
    fail('Бот не нашёл допустимого намерения для $seat');
  }

  /// Все неcозданные карты партии, где бы они ни лежали.
  List<CardInstanceId> cardsInPlay(MatchState state) {
    final created = {
      for (final id in ['vildkaarl', 'young_vildkaarl', 'bovine', 'heimdall']) CardId(id),
    };
    return [
      for (final seat in Seat.values) ...[
        ...state.player(seat).deck,
        ...state.player(seat).hand,
        ...state.player(seat).discard,
        for (final row in state.player(seat).rows.values) ...[
          for (final card in row.cards) ...[card.card, ?card.beneath],
          if (row.slot case CardSlot(:final card)) card,
        ],
      ],
      for (final weather in state.weather) weather.card,
      // Карты, которые уже покинули руку, колоду или отбой, но ещё ждут выхода на поле (например, выбора ряда).
      for (final effect in state.effects)
        if (effect case EnterFieldEffect(:final card)) card,
    ].where((card) => !created.contains(card.cardId)).map((card) => card.id).toList()..sort(
      (a, b) => a.value.compareTo(b.value),
    );
  }

  ({MatchState state, List<GameEvent> events}) simulate(int seed) {
    final (one, two) = pairings[seed % pairings.length];
    final started = engine.start(MatchSetup(decks: {Seat.one: one, Seat.two: two}, rng: SeededRng(seed)));
    var result = started as Accepted;
    final events = [...result.events];
    final initial = cardsInPlay(result.state);
    for (var turn = 0; result.state.phase != MatchPhase.finished; turn++) {
      if (turn > 500) fail('Партия не закончилась за 500 шагов');
      result = step(engine, result.state, turn);
      events.addAll(result.events);
      expect(cardsInPlay(result.state), initial, reason: 'карты не теряются и не дублируются');
      for (final seat in Seat.values) {
        final view = engine.project(result.state, seat);
        expect(view.opponent.hand, isNull);
        expect(view.opponent.handCount, result.state.player(seat.opponent).hand.length);
        expect(
          engine.eventsFor(result.events, seat).whereType<CardsDrawn>().every((event) => event.seat == seat),
          isTrue,
          reason: 'чужие взятые карты не видны',
        );
      }
    }
    return (state: result.state, events: events);
  }

  test('партии с разными сидами доигрываются до конца без потери карт', () {
    for (var seed = 1; seed <= 40; seed++) {
      final match = simulate(seed);
      expect(match.state.outcome, isNotNull);
      expect(match.state.history.length, inInclusiveRange(2, 3));
    }
  });

  test('одинаковый сид и одинаковые намерения дают одинаковую партию', () {
    final first = simulate(42);
    final second = simulate(42);
    expect(second.state, first.state);
    expect(second.events, first.events);
  });
}
