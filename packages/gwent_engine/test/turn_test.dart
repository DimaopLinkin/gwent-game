import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/match_builder.dart';

/// Разделы 4 и 5 правил: ход, пас и автопас.
void main() {
  test('сыгранная карта передаёт ход сопернику', () {
    final state = playing(
      one: const Side(hand: ['footman']),
      two: const Side(hand: ['archer']),
    );
    final card = find(state, Seat.one, 'footman');
    final result = act(engine, state, Seat.one, PlayCard(card));
    expect(result.state.turn, Seat.two);
    expect(rowCards(result.state, Seat.one, Row.melee), ['footman']);
    expect(result.events, [
      CardPlayed(Seat.one, CardInstance(card, const CardId('footman'))),
      UnitPlaced(Seat.one, Row.melee, CardInstance(card, const CardId('footman')), EntrySource.hand),
      const TurnStarted(Seat.two),
    ]);
  });

  test('если соперник спасовал, ход остаётся у игрока', () {
    final state = playing(
      one: const Side(hand: ['footman', 'archer']),
      two: const Side(hand: ['archer'], passed: true),
    );
    final result = act(engine, state, Seat.one, PlayCard(find(state, Seat.one, 'footman')));
    expect(result.state.turn, Seat.one);
  });

  test('чужой ход, карта не из руки и повторный ход после паса отклоняются', () {
    final state = playing(
      one: const Side(hand: ['footman']),
      two: const Side(hand: ['archer']),
    );
    expect(rejected(engine, state, Seat.two, PlayCard(find(state, Seat.two, 'archer'))), RejectReason.notYourTurn);
    expect(rejected(engine, state, Seat.one, PlayCard(find(state, Seat.two, 'archer'))), RejectReason.cardNotInHand);

    final passed = act(engine, state, Seat.one, const Pass()).state;
    expect(passed.turn, Seat.two);
    expect(rejected(engine, passed, Seat.one, const Pass()), RejectReason.alreadyPassed);
  });

  test('пас: второй пас заканчивает раунд', () {
    final state = playing(
      one: const Side(hand: ['footman'], melee: ['vesemir']),
      two: const Side(hand: ['archer']),
    );
    final first = act(engine, state, Seat.one, const Pass());
    expect(first.events, [const Passed(Seat.one, auto: false), const TurnStarted(Seat.two)]);
    final second = act(engine, first.state, Seat.two, const Pass());
    expect(second.events.whereType<RoundEnded>().single.result.winner, Seat.one);
    expect(second.state.round, 2);
  });

  group('ряд при розыгрыше', () {
    final state = playing(
      one: const Side(hand: ['elf_skirmisher', 'footman', 'horn']),
      two: const Side(hand: ['archer']),
    );

    test('проворной карте нужен ближний или дальний ряд', () {
      final elf = find(state, Seat.one, 'elf_skirmisher');
      expect(rejected(engine, state, Seat.one, PlayCard(elf)), RejectReason.rowRequired);
      expect(rejected(engine, state, Seat.one, PlayCard(elf, row: Row.siege)), RejectReason.invalidRow);
      final result = act(engine, state, Seat.one, PlayCard(elf, row: Row.ranged));
      expect(rowCards(result.state, Seat.one, Row.ranged), ['elf_skirmisher']);
    });

    test('обычную карту нельзя положить в чужой ряд', () {
      final footman = find(state, Seat.one, 'footman');
      expect(rejected(engine, state, Seat.one, PlayCard(footman, row: Row.siege)), RejectReason.invalidRow);
      expect(act(engine, state, Seat.one, PlayCard(footman, row: Row.melee)).state.turn, Seat.two);
    });

    test('Командирскому рогу нужен ряд со свободным слотом', () {
      final horn = find(state, Seat.one, 'horn');
      expect(rejected(engine, state, Seat.one, PlayCard(horn)), RejectReason.rowRequired);
      final result = act(engine, state, Seat.one, PlayCard(horn, row: Row.siege));
      expect(result.state.player(Seat.one).rows[Row.siege]!.slot, CardSlot(CardInstance(horn, const CardId('horn'))));
    });

    test('в занятый слот рог положить нельзя', () {
      final occupied = playing(
        one: const Side(hand: ['horn'], slots: {Row.melee: 'horn'}),
        two: const Side(hand: ['archer']),
      );
      expect(
        rejected(engine, occupied, Seat.one, PlayCard(find(occupied, Seat.one, 'horn'), row: Row.melee)),
        RejectReason.slotOccupied,
      );
    });
  });

  group('автопас', () {
    test('игрок без допустимых действий пасует сам, вплоть до конца партии', () {
      final state = playing(
        one: const Side(hand: ['footman'], leaderUsed: true),
        two: const Side(leaderUsed: true, crystals: 1),
      );
      final result = act(engine, state, Seat.one, PlayCard(find(state, Seat.one, 'footman')));
      expect(result.events.whereType<Passed>(), [
        const Passed(Seat.two, auto: true),
        const Passed(Seat.one, auto: true),
      ]);
      expect(result.state.phase, MatchPhase.finished);
      expect(result.state.outcome, const MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals));
    });

    test('доступный лидер — допустимое действие', () {
      final state = playing(
        one: const Side(hand: ['footman'], leaderUsed: true),
      );
      final result = act(engine, state, Seat.one, PlayCard(find(state, Seat.one, 'footman')));
      expect(result.state.turn, Seat.two);
    });

    test('пассивный лидер и Чучело без цели — нет допустимых действий', () {
      final state = playing(
        one: const Side(hand: ['footman'], leaderUsed: true),
        two: const Side(leader: 'bran', faction: Faction.skellige, hand: ['decoy']),
      );
      final result = act(engine, state, Seat.one, PlayCard(find(state, Seat.one, 'footman')));
      expect(result.events, contains(const Passed(Seat.two, auto: true)));
    });

    test('рог без свободного слота сыграть нельзя', () {
      final state = playing(
        one: const Side(hand: ['footman'], leaderUsed: true),
        two: const Side(
          hand: ['horn'],
          leaderUsed: true,
          slots: {Row.melee: 'horn', Row.ranged: 'horn', Row.siege: 'leader_horn'},
        ),
      );
      final result = act(engine, state, Seat.one, PlayCard(find(state, Seat.one, 'footman')));
      expect(result.events, contains(const Passed(Seat.two, auto: true)));
    });
  });

  test('сдача заканчивает партию победой соперника', () {
    final state = playing(
      one: const Side(hand: ['footman']),
      two: const Side(hand: ['archer']),
    );
    final result = act(engine, state, Seat.two, const Resign());
    expect(result.state.outcome, const MatchOutcome(winner: Seat.one, reason: MatchEndReason.resignation));
    expect(rejected(engine, result.state, Seat.one, const Pass()), RejectReason.matchFinished);
  });

  test('проекция показывает, какие карты можно сыграть в свой ход', () {
    final state = playing(
      one: const Side(hand: ['footman', 'decoy']),
      two: const Side(hand: ['archer']),
    );
    expect(engine.project(state, Seat.one).me.playable, {find(state, Seat.one, 'footman')});
    expect(engine.project(state, Seat.two).me.playable, isEmpty);
  });
}
