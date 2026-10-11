import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/match_builder.dart';
import 'support/scripted_rng.dart';

/// Раздел 10 правил: способности лидеров.
void main() {
  const opponent = Side(hand: ['archer']);

  Accepted lead(MatchState state, {Seat seat = Seat.one}) => act(engine, state, seat, const UseLeader());

  Accepted choose(Accepted result, ChoiceOption option, {Seat seat = Seat.one}) =>
      act(engine, result.state, seat, ChooseOption(option));

  group('общие правила', () {
    test('способность применяется один раз за партию и тратит ход, даже без эффекта', () {
      final state = playing(
        one: const Side(leader: 'foltest_fog', hand: ['footman']),
        two: opponent,
      );
      final result = lead(state);
      expect(result.events.first, const LeaderUsed(Seat.one, LeaderId('foltest_fog')));
      expect(result.state.turn, Seat.two);
      expect(result.state.player(Seat.one).leaderUsed, isTrue);

      final back = act(engine, result.state, Seat.two, PlayCard(find(result.state, Seat.two, 'archer'))).state;
      expect(rejected(engine, back, Seat.one, const UseLeader()), RejectReason.leaderUnavailable);
    });

    test('пассивную способность нельзя применить как ход', () {
      final state = playing(
        one: const Side(leader: 'bran', faction: Faction.skellige, hand: ['footman']),
        two: opponent,
      );
      expect(rejected(engine, state, Seat.one, const UseLeader()), RejectReason.leaderUnavailable);
    });

    test('Белое Пламя соперника отключает способность', () {
      final state = playing(
        one: const Side(hand: ['footman']),
        two: const Side(leader: 'emgyr_white_flame', faction: Faction.nilfgaard, hand: ['archer']),
      );
      expect(rejected(engine, state, Seat.one, const UseLeader()), RejectReason.leaderUnavailable);
      expect(engine.project(state, Seat.one).me.leaderAvailable, isFalse);
    });
  });

  group('погода из колоды', () {
    test('Король Темерии берёт Мглу из колоды и играет её', () {
      final state = playing(
        one: const Side(leader: 'foltest_fog', deck: ['footman', 'fog']),
        two: opponent,
      );
      final result = lead(state);
      expect(names([for (final weather in result.state.weather) weather.card]), ['fog']);
      expect(result.state.weather.single.owner, Seat.one);
      expect(names(result.state.player(Seat.one).deck), ['footman']);
    });

    test('Истинная эльфка при уже лежащем Морозе: карта сразу уходит в отбой', () {
      final state = playing(
        one: const Side(leader: 'francesca_frost', faction: Faction.scoiatael, deck: ['frost']),
        two: opponent,
        weather: [('frost', Seat.two)],
      );
      final result = lead(state);
      expect(result.state.weather, hasLength(1));
      expect(names(result.state.player(Seat.one).discard), ['frost']);
    });

    test('Командир Дикой Охоты выбирает любую погоду или Ясное небо из колоды', () {
      final state = playing(
        one: const Side(leader: 'eredin_weather', faction: Faction.monsters, deck: ['footman', 'rain', 'clear']),
        two: opponent,
        weather: [('frost', Seat.two)],
      );
      final asked = lead(state);
      expect(asked.state.choice?.kind, ChoiceKind.deckWeather);
      expect(asked.state.choice?.options, [
        CardOption(instance(state, Seat.one, 'rain')),
        CardOption(instance(state, Seat.one, 'clear')),
      ]);
      final result = choose(asked, CardOption(instance(state, Seat.one, 'clear')));
      expect(result.state.weather, isEmpty);
      expect(names(result.state.player(Seat.one).discard), ['clear']);
      expect(result.state.turn, Seat.two);
    });
  });

  test('Предводитель Севера снимает всю погоду', () {
    final state = playing(
      one: const Side(hand: ['footman']),
      two: opponent,
      weather: [('rain', Seat.two)],
    );
    final result = lead(state);
    expect(result.state.weather, isEmpty);
    expect(names(result.state.player(Seat.two).discard), ['rain']);
  });

  group('рог лидера', () {
    test('кладётся в слот своего ряда и удваивает отряды', () {
      final state = playing(
        one: const Side(leader: 'foltest_horn', siege: ['catapult']),
        two: opponent,
      );
      final result = lead(state);
      expect(result.state.player(Seat.one).rows[Row.siege]!.slot, const LeaderHornSlot());
      expect(engine.project(result.state, Seat.one).me.rows[Row.siege]!.strength, 16);
    });

    test('если слот занят, эффекта нет', () {
      final state = playing(
        one: const Side(leader: 'foltest_horn', slots: {Row.siege: 'horn'}),
        two: opponent,
      );
      final result = lead(state);
      expect(result.state.player(Seat.one).rows[Row.siege]!.slot, isA<CardSlot>());
      expect(result.state.turn, Seat.two);
    });
  });

  test('Железный Владыка: Казнь по осадному ряду соперника с порогом 10', () {
    final state = playing(
      one: const Side(leader: 'foltest_siege_scorch'),
      two: const Side(hand: ['archer'], siege: ['catapult', 'banner_medic']),
    );
    final result = lead(state);
    expect(rowCards(result.state, Seat.two, Row.siege), ['banner_medic']);
  });

  group('Император Нильфгаарда', () {
    test('показывает 3 случайные карты руки соперника только этому игроку', () {
      final state = playing(
        one: const Side(leader: 'emgyr_reveal', faction: Faction.nilfgaard),
        two: const Side(hand: ['footman', 'archer', 'catapult', 'ghoul']),
        rng: const ScriptedRng([3, 0, 1]),
      );
      final result = lead(state);
      final revealed = result.events.whereType<HandRevealed>().single;
      expect(names(revealed.cards), ['ghoul', 'footman', 'catapult']);
      expect(engine.eventsFor(result.events, Seat.two).whereType<HandRevealed>(), isEmpty);
      expect(result.state.player(Seat.two).hand, hasLength(4));
    });

    test('если карт меньше трёх, показывает все без генератора', () {
      final state = playing(
        one: const Side(leader: 'emgyr_reveal', faction: Faction.nilfgaard),
        two: const Side(hand: ['footman', 'archer']),
        rng: const ScriptedRng([]),
      );
      expect(names(lead(state).events.whereType<HandRevealed>().single.cards), ['footman', 'archer']);
    });
  });

  group('карты из отбоя', () {
    test('Властелин Юга забирает обычный отряд из отбоя соперника', () {
      final state = playing(
        one: const Side(leader: 'emgyr_take', faction: Faction.nilfgaard),
        two: const Side(hand: ['archer'], discard: ['geralt', 'catapult', 'decoy']),
      );
      final asked = lead(state);
      expect(asked.state.choice?.kind, ChoiceKind.opponentDiscardCard);
      expect(asked.state.choice?.options, [CardOption(instance(state, Seat.two, 'catapult'))]);
      final result = choose(asked, CardOption(instance(state, Seat.two, 'catapult')));
      expect(names(result.state.player(Seat.one).hand), ['catapult']);
      expect(names(result.state.player(Seat.two).discard), ['geralt', 'decoy']);
    });

    test('Владыка Тир на Лиа возвращает обычный отряд из своего отбоя', () {
      final state = playing(
        one: const Side(leader: 'eredin_return', faction: Faction.monsters, discard: ['ghoul', 'geralt']),
        two: opponent,
      );
      final result = choose(lead(state), CardOption(instance(state, Seat.one, 'ghoul')));
      expect(names(result.state.player(Seat.one).hand), ['ghoul']);
    });

    test('без подходящих карт ничего не происходит, ход тратится', () {
      final state = playing(
        one: const Side(leader: 'eredin_return', faction: Faction.monsters, discard: ['geralt']),
        two: opponent,
      );
      final result = lead(state);
      expect(result.state.choice, isNull);
      expect(result.state.turn, Seat.two);
    });
  });

  test('Убийца Оберона: сбросить 2 карты из руки, затем выбрать 1 карту колоды', () {
    final state = playing(
      one: const Side(
        leader: 'eredin_oberon',
        faction: Faction.monsters,
        hand: ['footman', 'archer', 'ghoul'],
        deck: ['catapult', 'geralt'],
      ),
      two: opponent,
    );
    var result = lead(state);
    expect(result.state.choice?.kind, ChoiceKind.handCardToDiscard);
    result = choose(result, CardOption(instance(state, Seat.one, 'footman')));
    result = choose(result, CardOption(instance(state, Seat.one, 'ghoul')));
    expect(result.state.choice?.kind, ChoiceKind.deckCard);
    result = choose(result, CardOption(instance(state, Seat.one, 'geralt')));
    expect(names(result.state.player(Seat.one).hand), ['archer', 'geralt']);
    expect(names(result.state.player(Seat.one).discard), ['footman', 'ghoul']);
    expect(result.state.turn, Seat.two);
    expect(engine.eventsFor(result.events, Seat.two), contains(const CardsDrawnHidden(Seat.one, 1)));
  });

  group('Надежда Aen Seidhe', () {
    test('переставляет проворные карты ради наибольшей суммы ближнего и дальнего рядов', () {
      final state = playing(
        one: const Side(
          leader: 'francesca_agile',
          faction: Faction.scoiatael,
          melee: ['elf_skirmisher', 'kejran'],
          ranged: ['archer'],
        ),
        two: opponent,
        weather: [('frost', Seat.two)],
      );
      final result = lead(state);
      expect(rowCards(result.state, Seat.one, Row.melee), ['kejran']);
      expect(rowCards(result.state, Seat.one, Row.ranged), ['archer', 'elf_skirmisher']);
      expect(result.events, contains(isA<UnitMoved>()));
    });

    test('при равной сумме ничего не двигает', () {
      final state = playing(
        one: const Side(
          leader: 'francesca_agile',
          faction: Faction.scoiatael,
          melee: ['elf_skirmisher'],
          ranged: ['harpy'],
        ),
        two: opponent,
      );
      final result = lead(state);
      expect(rowCards(result.state, Seat.one, Row.melee), ['elf_skirmisher']);
      expect(result.events.whereType<UnitMoved>(), isEmpty);
    });

    test('героев не двигает и переносит только те карты, которым это выгодно', () {
      final state = playing(
        one: const Side(
          leader: 'francesca_agile',
          faction: Faction.scoiatael,
          melee: ['kejran', 'elf_skirmisher', 'harpy'],
          ranged: ['elf_skirmisher'],
        ),
        two: opponent,
        weather: [('frost', Seat.two)],
      );
      final result = lead(state);
      // Под Морозом Эльф в ближнем ряду даёт 1 + 1 от Кейрана, в дальнем 6: переходит. Гарпия даёт 2 в обоих
      // рядах: остаётся, потому что из равных раскладок берётся та, где перемещений меньше. Кейран — герой.
      expect(rowCards(result.state, Seat.one, Row.melee), ['kejran', 'harpy']);
      expect(rowCards(result.state, Seat.one, Row.ranged), ['elf_skirmisher', 'elf_skirmisher']);
      expect(result.events.whereType<UnitMoved>(), hasLength(1));
    });
  });

  test('Надежда Aen Seidhe: из равных раскладок с равным числом перемещений первая по порядку карта остаётся', () {
    // Два Олафа вместе дают 13 + 13 в любом ряду; вместе их собирает одно перемещение в любую сторону.
    final state = playing(
      one: const Side(leader: 'francesca_agile', faction: Faction.scoiatael, melee: ['olaf'], ranged: ['olaf']),
      two: opponent,
    );
    final result = lead(state);
    expect(rowCards(result.state, Seat.one, Row.melee), ['olaf', 'olaf']);
    expect(rowCards(result.state, Seat.one, Row.ranged), isEmpty);
    expect(result.events.whereType<UnitMoved>(), hasLength(1));
  });

  test('Убийца Оберона с пустой рукой и колодой ничего не делает', () {
    final state = playing(
      one: const Side(leader: 'eredin_oberon', faction: Faction.monsters),
      two: opponent,
    );
    final result = lead(state);
    expect(result.state.choice, isNull);
    expect(result.state.turn, Seat.two);
  });

  test('Крах ан Крайт замешивает отбой каждого игрока в его колоду', () {
    final state = playing(
      one: const Side(leader: 'crach', faction: Faction.skellige, deck: ['footman'], discard: ['archer', 'catapult']),
      two: const Side(hand: ['archer'], discard: ['ghoul']),
    );
    final result = lead(state);
    expect(result.state.player(Seat.one).discard, isEmpty);
    expect(result.state.player(Seat.two).discard, isEmpty);
    expect(names(result.state.player(Seat.one).deck)..sort(), ['archer', 'catapult', 'footman']);
    expect(names(result.state.player(Seat.two).deck), ['ghoul']);
    expect(result.events.whereType<DiscardShuffledIntoDeck>(), const [
      DiscardShuffledIntoDeck(Seat.one),
      DiscardShuffledIntoDeck(Seat.two),
    ]);
  });

  test('Крах ан Крайт: генератор сначала перемешивает колоду применившего, затем соперника', () {
    final state = playing(
      one: const Side(leader: 'crach', faction: Faction.skellige, deck: ['footman'], discard: ['archer']),
      two: const Side(hand: ['archer'], deck: ['ghoul'], discard: ['catapult']),
      // Колода из двух карт перемешивается одним числом: 0 меняет карты местами, 1 оставляет.
      rng: const ScriptedRng([0, 1]),
    );
    final result = lead(state);
    expect(names(result.state.player(Seat.one).deck), ['archer', 'footman']);
    expect(names(result.state.player(Seat.two).deck), ['ghoul', 'catapult']);
  });
}
