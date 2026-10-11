import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/match_builder.dart';
import 'support/scripted_rng.dart';

/// Раздел 3 правил: подготовка партии и пересдача.
void main() {
  Deck deck(String leader, List<String> cards) =>
      Deck(leader: LeaderId(leader), cards: [for (final card in cards) CardId(card)]);

  final filler = [for (var i = 0; i < 14; i++) i.isEven ? 'footman' : 'archer'];
  final northern = deck('foltest_clear', filler);
  final monsters = deck('eredin_return', [for (var i = 0; i < 14; i++) i.isEven ? 'ghoul' : 'archer']);
  final scoiatael = deck('francesca_frost', ['elf_skirmisher', 'elf_skirmisher', ...filler.take(12)]);

  Accepted start(Deck one, Deck two, {Rng rng = const SeededRng(7), GwentEngine? with_}) {
    final result = (with_ ?? engine).start(MatchSetup(decks: {Seat.one: one, Seat.two: two}, rng: rng));
    if (result is! Accepted) fail('Партия не создана: ${(result as Rejected).reject}');
    return result;
  }

  test('раздача по 10 карт, монетка, затем пересдача', () {
    final started = start(northern, monsters);
    final state = started.state;
    expect(state.phase, MatchPhase.redraw);
    expect(state.player(Seat.one).hand, hasLength(10));
    expect(state.player(Seat.one).deck, hasLength(4));
    expect(state.player(Seat.two).hand, hasLength(10));
    expect(state.roundStarter, isNotNull);
    expect(
      started.events.whereType<FirstPlayerChosen>().single,
      FirstPlayerChosen(state.roundStarter!, byChoice: false),
    );
    expect(started.events.map((event) => event.runtimeType), [
      DeckShuffled,
      DeckShuffled,
      FirstPlayerChosen,
      CardsDrawn,
      CardsDrawn,
    ]);
  });

  test('одинаковый сид даёт одинаковую партию, другой сид — другую', () {
    expect(start(northern, monsters).state, start(northern, monsters).state);
    expect(start(northern, monsters).state, isNot(start(northern, monsters, rng: const SeededRng(8)).state));
  });

  test('номера экземпляров идут по перемешанной колоде', () {
    final state = start(northern, monsters).state;
    expect([for (final card in state.player(Seat.one).hand) card.id.value], [for (var i = 1; i <= 10; i++) i]);
    expect([for (final card in state.player(Seat.two).hand) card.id.value], [for (var i = 15; i <= 24; i++) i]);
  });

  test('монетка: число генератора выбирает игрока', () {
    // Колоды из одной карты перемешиваются без вызовов генератора, поэтому первое число — монетка.
    final one = deck('foltest_clear', ['footman']);
    final two = deck('eredin_return', ['ghoul']);
    expect(start(one, two, rng: const ScriptedRng([0])).state.roundStarter, Seat.one);
    expect(start(one, two, rng: const ScriptedRng([1])).state.roundStarter, Seat.two);
  });

  group("Скоя'таэли", () {
    test("единственный игрок Скоя'таэлей решает, кто ходит первым, до раздачи", () {
      final started = start(northern, scoiatael);
      expect(started.state.phase, MatchPhase.choosingFirstPlayer);
      expect(started.state.player(Seat.one).hand, isEmpty);
      expect(
        started.state.choice,
        const PendingChoice(
          seat: Seat.two,
          kind: ChoiceKind.firstPlayer,
          options: [SeatOption(Seat.one), SeatOption(Seat.two)],
        ),
      );
      expect(
        rejected(engine, started.state, Seat.one, const ChooseOption(SeatOption(Seat.one))),
        RejectReason.notYourChoice,
      );
      expect(
        rejected(engine, started.state, Seat.two, const RedrawCard(CardInstanceId(1))),
        RejectReason.choicePending,
      );

      final chosen = act(engine, started.state, Seat.two, const ChooseOption(SeatOption(Seat.one)));
      expect(chosen.state.phase, MatchPhase.redraw);
      expect(chosen.state.roundStarter, Seat.one);
      expect(chosen.events.first, const FirstPlayerChosen(Seat.one, byChoice: true));
      expect(chosen.state.player(Seat.one).hand, hasLength(10));
    });

    test("Скоя'таэли у обоих: монетка", () {
      final started = start(scoiatael, scoiatael);
      expect(started.state.phase, MatchPhase.redraw);
      expect(started.events.whereType<FirstPlayerChosen>().single.byChoice, isFalse);
    });
  });

  group('лидеры при подготовке', () {
    test('Маргаритка из Долин: 11 карт', () {
      final daisy = deck('francesca_daisy', filler);
      // Скоя'таэли у обоих: монетка, раздача сразу.
      expect(start(daisy, scoiatael).state.player(Seat.one).hand, hasLength(11));
    });

    test('Белое Пламя отключает лидера соперника, в том числе пассивного', () {
      final daisy = deck('francesca_daisy', filler);
      final flame = deck('emgyr_white_flame', filler);
      final started = start(daisy, flame).state;
      final state = act(engine, started, Seat.one, const ChooseOption(SeatOption(Seat.one))).state;
      expect(state.player(Seat.one).leaderDisabled, isTrue);
      expect(state.player(Seat.two).leaderDisabled, isFalse);
      expect(state.player(Seat.one).hand, hasLength(10));
    });

    test('Белое Пламя у обоих отключает обоих', () {
      final flame = deck('emgyr_white_flame', filler);
      final state = start(flame, flame).state;
      expect(state.player(Seat.one).leaderDisabled, isTrue);
      expect(state.player(Seat.two).leaderDisabled, isTrue);
    });
  });

  test('колода, нарушающая правила сборки, не допускается', () {
    final result = engineWith(rules: const GameRules()).start(
      MatchSetup(decks: {Seat.one: northern, Seat.two: monsters}, rng: const SeededRng(1)),
    );
    expect(
      result,
      const Rejected(
        Reject(RejectReason.invalidDeck, seat: Seat.one, deckViolations: [TooFewUnitCards(count: 14, min: 22)]),
      ),
    );
  });

  group('пересдача', () {
    test('карта уходит под низ колоды, на её место приходит верхняя', () {
      final state = start(northern, monsters).state;
      final hand = state.player(Seat.one).hand;
      final deckTop = state.player(Seat.one).deck.first;
      final result = act(engine, state, Seat.one, RedrawCard(hand[3].id));
      final player = result.state.player(Seat.one);
      expect(player.hand[3], deckTop);
      expect(player.deck.last, hand[3]);
      expect(player.redrawsLeft, 1);
      expect(result.events, [CardRedrawn(Seat.one, returned: hand[3], drawn: deckTop)]);
    });

    test('после двух замен пересдача заканчивается сама', () {
      var state = start(northern, monsters).state;
      state = act(engine, state, Seat.one, RedrawCard(state.player(Seat.one).hand[0].id)).state;
      final second = act(engine, state, Seat.one, RedrawCard(state.player(Seat.one).hand[1].id));
      expect(second.events.last, const RedrawFinished(Seat.one));
      expect(
        rejected(engine, second.state, Seat.one, RedrawCard(second.state.player(Seat.one).hand[2].id)),
        RejectReason.redrawFinished,
      );
    });

    test('игроки пересдают независимо; после обоих колоды перемешиваются и начинается раунд 1', () {
      var state = start(northern, monsters).state;
      final first = state.roundStarter!;
      state = act(engine, state, Seat.two, const FinishRedraw()).state;
      expect(state.phase, MatchPhase.redraw);
      expect(rejected(engine, state, Seat.two, const FinishRedraw()), RejectReason.redrawFinished);
      expect(rejected(engine, state, Seat.one, const Pass()), RejectReason.wrongPhase);

      final result = act(engine, state, Seat.one, const FinishRedraw());
      expect(result.state.phase, MatchPhase.playing);
      expect(result.state.round, 1);
      expect(result.state.turn, first);
      expect(result.events, [
        const RedrawFinished(Seat.one),
        const DeckShuffled(Seat.one),
        const DeckShuffled(Seat.two),
        RoundStarted(1, first),
        TurnStarted(first),
      ]);
    });

    test('замена карты не из руки отклоняется', () {
      final state = start(northern, monsters).state;
      final notInHand = state.player(Seat.one).deck.first.id;
      expect(rejected(engine, state, Seat.one, RedrawCard(notInHand)), RejectReason.cardNotInHand);
    });

    test('сопернику не видно, какие карты заменены', () {
      final state = start(northern, monsters).state;
      final result = act(engine, state, Seat.one, RedrawCard(state.player(Seat.one).hand[0].id));
      expect(engine.eventsFor(result.events, Seat.two), isEmpty);
      expect(engine.eventsFor(result.events, Seat.one), result.events);
      expect(engine.project(result.state, Seat.two).opponent.redrawsLeft, isNull);
      expect(engine.project(result.state, Seat.two).opponent.hand, isNull);
    });
  });
}
