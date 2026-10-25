import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/match_builder.dart';

/// Решения жадного бота в характерных позициях. Бот везде играет за игрока 1.
void main() {
  final bot = GreedyBot(engine, catalog);
  const me = Seat.one;

  /// Намерение бота; тест падает, если бот промолчал.
  Intent decide(MatchState state, {Seat seat = me}) => bot.decide(state, seat) ?? fail('Бот промолчал');

  /// Сыграна ли карта [card] из руки бота (в любой ряд и на любую цель).
  Matcher plays(MatchState state, String card) =>
      isA<PlayCard>().having((intent) => intent.card, 'card', find(state, me, card));

  /// Выбрана ли карта [card] из зоны игрока [owner].
  Matcher picks(MatchState state, String card, {Seat owner = me}) => isA<ChooseOption>().having(
    (intent) => intent.option,
    'option',
    isA<CardOption>().having((option) => option.card.id, 'card', find(state, owner, card)),
  );

  /// Применяет намерение и требует, чтобы движок его принял.
  MatchState act(MatchState state, Seat seat, Intent intent) => switch (engine.apply(state, seat, intent)) {
    Accepted(:final state) => state,
    Rejected(:final reject) => fail('Намерение $intent отклонено: ${reject.reason}'),
  };

  group('рог и занятые слоты', () {
    test('бот не тратит рог на занятый слот, когда свободных нет', () {
      final state = playing(
        one: const Side(
          hand: ['horn', 'mardrem'],
          slots: {Row.melee: 'horn', Row.ranged: 'horn', Row.siege: 'leader_horn'},
          melee: ['footman'],
        ),
        two: const Side(melee: ['footman'], passed: true),
      );
      expect(decide(state), const Pass());
    });

    test('рог бот кладёт только в свободный слот', () {
      final state = playing(
        one: const Side(hand: ['horn'], slots: {Row.melee: 'horn', Row.siege: 'leader_horn'}, ranged: ['archer']),
        two: const Side(melee: ['footman'], passed: true),
      );
      expect(decide(state), isA<PlayCard>().having((intent) => intent.row, 'row', Row.ranged));
    });
  });

  group('соперник спасовал', () {
    test('бот впереди и пасует, не тратя карты', () {
      final state = playing(
        one: const Side(hand: ['geralt'], melee: ['vesemir']),
        two: const Side(melee: ['footman'], passed: true),
      );
      expect(decide(state), const Pass());
    });

    test('бот отстаёт и играет самую дешёвую карту, которая выводит вперёд', () {
      final state = playing(
        one: const Side(hand: ['geralt', 'footman', 'vesemir']),
        two: const Side(melee: ['footman'], passed: true),
      );
      expect(decide(state), plays(state, 'vesemir'));
    });

    test('при безнадёжном отставании бот сдаёт раунд, если у него два кристалла', () {
      final state = playing(
        one: const Side(hand: ['footman']),
        two: const Side(melee: ['geralt', 'vesemir'], passed: true),
      );
      expect(decide(state), const Pass());
    });

    test('на последнем кристалле бот играет до конца', () {
      final state = playing(
        one: const Side(hand: ['footman'], crystals: 1),
        two: const Side(melee: ['geralt', 'vesemir'], passed: true),
      );
      expect(decide(state), plays(state, 'footman'));
    });

    test('при двух кристаллах бот не тратит руку, чтобы догнать соперника', () {
      final state = playing(
        one: const Side(hand: ['footman', 'footman', 'footman', 'footman', 'footman', 'footman', 'footman', 'footman']),
        two: const Side(
          melee: ['geralt', 'vesemir'],
          hand: ['footman', 'footman', 'footman', 'footman', 'footman', 'footman'],
          passed: true,
        ),
      );
      expect(decide(state), const Pass());
    });

    test('на последнем кристалле бот догоняет очками, а не берёт карты Шпионом', () {
      final state = playing(
        one: const Side(
          leader: 'eredin_return',
          faction: Faction.monsters,
          hand: ['harpy', 'harpy', 'harpy', 'skellen'],
          melee: ['poor_infantry'],
          deck: ['ghoul', 'ghoul', 'ghoul'],
          crystals: 1,
        ),
        two: const Side(melee: ['footman'], ranged: ['archer'], passed: true, crystals: 1),
        round: 3,
      );
      expect(decide(state), plays(state, 'harpy'));
    });
  });

  group('соперник ещё играет', () {
    test('с большим отрывом и двумя кристаллами бот пасует', () {
      final state = playing(
        one: const Side(hand: ['footman'], melee: ['geralt']),
      );
      expect(decide(state), const Pass());
    });

    test('на последнем кристалле бот не пасует, пока соперник может ответить', () {
      final state = playing(
        one: const Side(hand: ['footman'], melee: ['geralt'], crystals: 1),
        two: const Side(hand: ['vesemir']),
      );
      expect(decide(state), plays(state, 'footman'));
    });

    test('на последнем кристалле бот пасует, если соперник ответить не может', () {
      final state = playing(
        one: const Side(hand: ['footman'], melee: ['geralt'], crystals: 1),
        two: const Side(leaderUsed: true),
      );
      expect(decide(state), const Pass());
    });

    test('с любым отрывом бот пасует, если соперник ответить не может', () {
      final state = playing(
        one: const Side(hand: ['footman'], melee: ['archer']),
        two: const Side(leaderUsed: true),
      );
      expect(decide(state), const Pass());
    });

    test('Шпион ценнее слабого отряда: две карты в руку', () {
      final state = playing(
        one: const Side(hand: ['footman', 'thaler'], deck: ['archer', 'archer', 'archer']),
      );
      expect(decide(state), plays(state, 'thaler'));
    });

    test('Казнь, которая бьёт свой сильнейший отряд, бот не играет', () {
      final state = playing(
        one: const Side(hand: ['scorch', 'archer'], melee: ['vesemir']),
        two: const Side(melee: ['geralt', 'footman']),
      );
      expect(decide(state), plays(state, 'archer'));
    });

    test('Казнь по сильнейшему отряду соперника бот играет', () {
      final state = playing(
        one: const Side(hand: ['scorch', 'archer'], melee: ['footman']),
        two: const Side(melee: ['vesemir']),
      );
      expect(decide(state), plays(state, 'scorch'));
    });

    test('Командирский рог идёт в ряд, где удваивает больше', () {
      final state = playing(
        one: const Side(hand: ['horn'], melee: ['footman', 'footman', 'footman'], ranged: ['archer']),
        two: const Side(melee: ['geralt']),
      );
      expect(decide(state), PlayCard(find(state, me, 'horn'), row: Row.melee));
    });

    test('проворный отряд встаёт в ряд без погоды', () {
      final state = playing(
        one: const Side(leader: 'francesca_agile', faction: Faction.scoiatael, hand: ['elf_skirmisher']),
        weather: [('frost', Seat.two)],
      );
      expect(decide(state), PlayCard(find(state, me, 'elf_skirmisher'), row: Row.ranged));
    });

    test('Медик поднимает сильнейший отряд из отбоя', () {
      var state = playing(
        one: const Side(hand: ['banner_medic'], discard: ['footman', 'vesemir']),
      );
      final intent = decide(state);
      expect(intent, plays(state, 'banner_medic'));
      state = act(state, me, intent);
      expect(state.choice?.kind, ChoiceKind.medicTarget);
      expect(decide(state), picks(state, 'vesemir'));
    });

    test('лидер со сбросом: бот сбрасывает слабые карты и берёт из колоды сильную', () {
      var state = playing(
        one: const Side(
          leader: 'eredin_oberon',
          faction: Faction.monsters,
          hand: ['ghoul', 'geralt', 'harpy'],
          deck: ['footman', 'catapult'],
        ),
      );
      state = act(state, me, const UseLeader());
      expect(state.choice?.kind, ChoiceKind.handCardToDiscard);
      final first = decide(state);
      expect(first, picks(state, 'ghoul'));
      state = act(state, me, first);
      expect(decide(state), picks(state, 'harpy'));
      state = act(state, me, decide(state));
      expect(state.choice?.kind, ChoiceKind.deckCard);
      expect(decide(state), picks(state, 'catapult'));
    });

    test('в ход соперника бот молчит', () {
      final state = playing(
        one: const Side(hand: ['footman']),
        two: const Side(hand: ['footman']),
        turn: Seat.two,
      );
      expect(bot.decide(state, me), isNull);
      expect(decide(state, seat: Seat.two), isA<Intent>());
    });
  });

  group('подготовка партии', () {
    Deck deck(String leader, List<String> cards) =>
        Deck(leader: LeaderId(leader), cards: [for (final card in cards) CardId(card)]);

    const strong = [
      'blue_stripes',
      'blue_stripes',
      'blue_stripes',
      'catapult',
      'catapult',
      'banner_medic',
      'vesemir',
      'geralt',
      'yennefer',
      'villentretenmerth',
    ];
    final northern = deck('foltest_clear', strong);

    test("Скоя'таэли уступают первый ход", () {
      final scoiatael = deck('francesca_agile', ['elf_skirmisher', 'footman', 'archer', ...strong.skip(6)]);
      final state =
          (engine.start(MatchSetup(one: scoiatael, two: northern, rng: const SeededRng(3))) as Accepted).state;
      expect(state.choice?.kind, ChoiceKind.firstPlayer);
      expect(decide(state), const ChooseOption(SeatOption(Seat.two)));
    });

    test('при пересдаче бот меняет самую слабую карту', () {
      final monsters = deck('eredin_return', ['ghoul', 'arachas', 'arachas', 'kejran', 'vesemir', 'geralt']);
      final state = (engine.start(MatchSetup(one: monsters, two: northern, rng: const SeededRng(5))) as Accepted).state;
      expect(state.phase, MatchPhase.redraw);
      expect(decide(state), RedrawCard(find(state, me, 'ghoul')));
    });

    test('при пересдаче бот не меняет сильного Шпиона', () {
      final nilfgaard = deck('emgyr_take', ['skellen', ...strong.skip(6)]);
      final state =
          (engine.start(MatchSetup(one: nilfgaard, two: northern, rng: const SeededRng(5))) as Accepted).state;
      expect(state.phase, MatchPhase.redraw);
      expect(decide(state), const FinishRedraw());
    });

    test('без слабых карт бот сразу заканчивает пересдачу', () {
      final state = (engine.start(MatchSetup(one: northern, two: northern, rng: const SeededRng(5))) as Accepted).state;
      expect(state.phase, MatchPhase.redraw);
      expect(decide(state), const FinishRedraw());
    });
  });
}
