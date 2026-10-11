import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/match_builder.dart';
import 'support/scripted_rng.dart';

/// Разделы 5–7 и 11 правил: итог раунда, уборка поля, конец партии и перки фракций.
void main() {
  /// Раунд заканчивается пасом игрока 1, игрок 2 уже спасовал. У обоих в руке остаются карты, чтобы
  /// следующий раунд не закончился автопасом.
  Accepted endRound({
    Side one = const Side(),
    Side two = const Side(),
    int round = 1,
    Seat starter = Seat.one,
    List<(String, Seat)> weather = const [],
    Rng rng = const SeededRng(1),
  }) => act(
    engine,
    playing(one: one, two: two, round: round, starter: starter, weather: weather, rng: rng),
    Seat.one,
    const Pass(),
  );

  group('итог раунда', () {
    test('проигравший теряет кристалл, следующий раунд начинает победитель', () {
      final result = endRound(
        one: const Side(hand: ['footman'], melee: ['vesemir']),
        two: const Side(hand: ['footman'], melee: ['footman'], passed: true),
        starter: Seat.two,
      );
      expect(
        result.state.history.single,
        const RoundResult(round: 1, scores: {Seat.one: 6, Seat.two: 3}, winner: Seat.one),
      );
      expect(result.state.player(Seat.two).crystals, 1);
      expect(result.state.player(Seat.one).crystals, 2);
      expect(result.state.round, 2);
      expect(result.state.roundStarter, Seat.one);
      expect(result.state.turn, Seat.one);
    });

    test('ничья без Нильфгаарда: оба теряют кристалл, начинает тот, кто начинал', () {
      final result = endRound(
        one: const Side(hand: ['footman'], melee: ['footman']),
        two: const Side(hand: ['footman'], melee: ['footman'], passed: true),
        starter: Seat.two,
      );
      expect(result.state.history.single.winner, isNull);
      expect(result.state.player(Seat.one).crystals, 1);
      expect(result.state.player(Seat.two).crystals, 1);
      expect(result.state.roundStarter, Seat.two);
    });

    test('ничья: единственный Нильфгаард выигрывает раунд', () {
      final result = endRound(
        one: const Side(hand: ['footman'], melee: ['footman']),
        two: const Side(
          leader: 'emgyr_reveal',
          faction: Faction.nilfgaard,
          hand: ['footman'],
          melee: ['footman'],
          passed: true,
        ),
      );
      expect(result.state.history.single.winner, Seat.two);
      expect(result.state.player(Seat.one).crystals, 1);
    });

    test('ничья при Нильфгаарде у обоих: оба теряют кристалл', () {
      const nilfgaard = Side(leader: 'emgyr_reveal', faction: Faction.nilfgaard, hand: ['footman']);
      final result = endRound(
        one: nilfgaard,
        two: const Side(leader: 'emgyr_reveal', faction: Faction.nilfgaard, hand: ['footman'], passed: true),
      );
      expect(result.state.history.single.winner, isNull);
      expect(result.state.player(Seat.one).crystals, 1);
      expect(result.state.player(Seat.two).crystals, 1);
    });
  });

  group('конец партии', () {
    test('победа, победа: 2:0 после раунда 2', () {
      final result = endRound(
        one: const Side(hand: ['footman'], melee: ['vesemir']),
        two: const Side(hand: ['footman'], crystals: 1, passed: true),
        round: 2,
      );
      expect(result.state.phase, MatchPhase.finished);
      expect(result.state.outcome, const MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals));
      expect(result.events.last, const MatchEnded(MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals)));
      expect(result.state.turn, isNull);
    });

    test('ничья при одном кристалле у обоих: ничья партии', () {
      final result = endRound(
        one: const Side(hand: ['footman'], crystals: 1),
        two: const Side(hand: ['footman'], crystals: 1, passed: true),
        round: 3,
      );
      expect(result.state.outcome, const MatchOutcome(winner: null, reason: MatchEndReason.crystals));
    });

    test('ничья, ничья без Нильфгаарда: ничья партии после раунда 2', () {
      var state = playing(
        one: const Side(hand: ['footman', 'archer']),
        two: const Side(hand: ['footman', 'archer']),
      );
      state = act(engine, state, Seat.one, const Pass()).state;
      state = act(engine, state, Seat.two, const Pass()).state;
      expect(state.round, 2);
      state = act(engine, state, Seat.one, const Pass()).state;
      final result = act(engine, state, Seat.two, const Pass());
      expect(result.state.history.map((round) => round.winner), [null, null]);
      expect(result.state.outcome?.winner, isNull);
      expect(result.state.phase, MatchPhase.finished);
    });
  });

  group('уборка поля', () {
    test('карты уходят в отбой хозяина, погода и рога снимаются, шпион уходит сопернику', () {
      final result = endRound(
        one: const Side(
          hand: ['footman'],
          melee: ['vesemir', 'skellen'],
          slots: {Row.melee: 'horn', Row.siege: 'leader_horn'},
        ),
        two: const Side(hand: ['footman'], ranged: ['archer'], passed: true),
        weather: [('frost', Seat.two)],
      );
      final one = result.state.player(Seat.one);
      for (final row in Row.values) {
        expect(one.rows[row], const RowState());
      }
      expect(names(one.discard), ['vesemir', 'skellen', 'horn']);
      expect(names(result.state.player(Seat.two).discard), ['archer', 'frost']);
      expect(result.state.weather, isEmpty);
    });

    test('созданная карта выходит из игры, Берсерк под ней уходит в отбой', () {
      final state = playing(
        one: const Side(hand: ['berserk', 'footman'], slots: {Row.melee: 'mardrem'}),
        two: const Side(hand: ['footman'], passed: true),
      );
      final played = act(engine, state, Seat.one, PlayCard(find(state, Seat.one, 'berserk'))).state;
      expect(rowCards(played, Seat.one, Row.melee), ['vildkaarl']);
      final result = act(engine, played, Seat.one, const Pass());
      expect(names(result.state.player(Seat.one).discard), ['berserk', 'mardrem']);
      expect(result.events.whereType<CardLeftGame>().single.card.cardId, const CardId('vildkaarl'));
    });

    test('Приманка призывает карту после уборки, и та остаётся в следующем раунде', () {
      final result = endRound(
        one: const Side(hand: ['footman'], ranged: ['cow']),
        two: const Side(hand: ['footman'], passed: true),
      );
      expect(names(result.state.player(Seat.one).discard), ['cow']);
      expect(rowCards(result.state, Seat.one, Row.melee), ['bovine']);

      // В конце следующего раунда созданная карта выходит из игры, а не в отбой.
      final next = playing(
        one: const Side(hand: ['footman'], melee: ['bovine']),
        two: const Side(hand: ['footman'], passed: true),
      );
      final cleared = act(engine, next, Seat.one, const Pass());
      expect(cleared.state.player(Seat.one).discard, isEmpty);
      expect(cleared.events.whereType<CardLeftGame>(), hasLength(1));
    });
  });

  group('перки фракций', () {
    test('Королевства Севера берут карту после выигранного раунда', () {
      final result = endRound(
        one: const Side(hand: ['footman'], deck: ['catapult', 'archer'], melee: ['vesemir']),
        two: const Side(leader: 'eredin_return', faction: Faction.monsters, hand: ['footman'], passed: true),
      );
      expect(names(result.state.player(Seat.one).hand), ['footman', 'catapult']);
      expect(result.events, contains(isA<CardsDrawn>()));
    });

    test('Королевства Севера не берут карту за ничью и за поражение', () {
      final tie = endRound(
        one: const Side(hand: ['footman'], deck: ['catapult']),
        two: const Side(hand: ['footman'], passed: true),
      );
      expect(names(tie.state.player(Seat.one).hand), ['footman']);

      final loss = endRound(
        one: const Side(hand: ['footman'], deck: ['catapult']),
        two: const Side(hand: ['footman'], melee: ['footman'], passed: true),
      );
      expect(names(loss.state.player(Seat.one).hand), ['footman']);
    });

    test('Чудовища оставляют случайную карту отряда; пометка снимается в начале раунда', () {
      final result = endRound(
        one: const Side(
          leader: 'eredin_return',
          faction: Faction.monsters,
          hand: ['footman'],
          melee: ['ghoul', 'vesemir'],
          siege: ['catapult'],
        ),
        two: const Side(hand: ['footman'], passed: true),
        // Кандидаты по порядку: ближний ряд (вурдалак, Весемир), затем осадный (катапульта).
        rng: const ScriptedRng([1]),
      );
      expect(rowCards(result.state, Seat.one, Row.melee), ['vesemir']);
      expect(result.state.player(Seat.one).rows[Row.melee]!.cards.single.kept, isFalse);
      expect(names(result.state.player(Seat.one).discard), ['ghoul', 'catapult']);
      expect(result.events, contains(isA<UnitKept>()));
    });

    test('Чудовища у обоих: генератор сначала выбирает за начинающего следующий раунд', () {
      const monsters = Side(
        leader: 'eredin_return',
        faction: Faction.monsters,
        hand: ['footman'],
        melee: ['ghoul', 'vesemir'],
      );
      // Ничья: следующий раунд снова начинает игрок 2, поэтому первое число — его.
      final result = endRound(
        one: monsters,
        two: const Side(
          leader: 'eredin_return',
          faction: Faction.monsters,
          hand: ['footman'],
          melee: ['ghoul', 'vesemir'],
          passed: true,
        ),
        starter: Seat.two,
        rng: const ScriptedRng([0, 1]),
      );
      expect(result.state.roundStarter, Seat.two);
      expect(rowCards(result.state, Seat.two, Row.melee), ['ghoul']);
      expect(rowCards(result.state, Seat.one, Row.melee), ['vesemir']);
    });

    test('Чудовища могут оставить героя и шпиона соперника, но не Чучело', () {
      final result = endRound(
        one: const Side(
          leader: 'eredin_return',
          faction: Faction.monsters,
          hand: ['footman'],
          melee: ['decoy', 'geralt'],
        ),
        two: const Side(hand: ['footman'], passed: true),
        rng: const ScriptedRng([0]),
      );
      expect(rowCards(result.state, Seat.one, Row.melee), ['geralt']);
    });

    test('оставленная Чудовищами Приманка ничего не призывает', () {
      final result = endRound(
        one: const Side(leader: 'eredin_return', faction: Faction.monsters, hand: ['footman'], ranged: ['cow']),
        two: const Side(hand: ['footman'], passed: true),
        rng: const ScriptedRng([0]),
      );
      expect(rowCards(result.state, Seat.one, Row.ranged), ['cow']);
      expect(rowCards(result.state, Seat.one, Row.melee), isEmpty);
    });

    test('Скеллиге в начале раунда 3 возвращает 2 случайных обычных отряда без способностей при выходе', () {
      final result = endRound(
        one: const Side(
          leader: 'bran',
          faction: Faction.skellige,
          hand: ['footman'],
          discard: ['geralt', 'banner_medic', 'archer', 'footman'],
          ranged: ['archer'],
        ),
        two: const Side(hand: ['footman'], passed: true),
        round: 2,
        // Подходят медик, лучник и пехотинец (Геральт — герой). Выбираются медик (0), затем пехотинец (1 из 2).
        rng: const ScriptedRng([0, 1]),
      );
      expect(result.state.round, 3);
      expect(rowCards(result.state, Seat.one, Row.siege), ['banner_medic']);
      expect(rowCards(result.state, Seat.one, Row.melee), ['footman']);
      expect(names(result.state.player(Seat.one).discard), ['geralt', 'archer', 'archer']);
      expect(result.state.choice, isNull);
      expect(result.events.whereType<UnitPlaced>().map((event) => event.source), everyElement(EntrySource.perk));
    });

    test('перк Скеллиге: ряд проворной карты выбирает игрок, шпион ложится на свою сторону', () {
      final result = endRound(
        one: const Side(hand: ['footman']),
        two: const Side(
          leader: 'bran',
          faction: Faction.skellige,
          hand: ['footman'],
          discard: ['elf_skirmisher', 'skellen'],
          melee: ['footman'],
          passed: true,
        ),
        round: 2,
        rng: const ScriptedRng([0, 0]),
      );
      expect(result.state.choice?.kind, ChoiceKind.unitRow);
      expect(result.state.choice?.seat, Seat.two);
      final chosen = act(engine, result.state, Seat.two, const ChooseOption(RowOption(Row.ranged)));
      expect(rowCards(chosen.state, Seat.two, Row.ranged), ['elf_skirmisher']);
      expect(rowCards(chosen.state, Seat.two, Row.melee), ['skellen']);
      expect(chosen.state.turn, Seat.two);
    });
  });
}
