import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/match_builder.dart';
import 'support/scripted_rng.dart';

/// Раздел 9 правил: специальные карты и способности отрядов.
void main() {
  /// Соперник с картой в руке, чтобы ход переходил к нему, а не заканчивался автопасом.
  const opponent = Side(hand: ['archer']);

  Accepted play(MatchState state, String card, {Row? row, String? target, Seat seat = Seat.one}) => act(
    engine,
    state,
    seat,
    PlayCard(find(state, seat, card), row: row, target: target == null ? null : find(state, seat, target)),
  );

  group('Шпион', () {
    test('ложится на сторону соперника, сыгравший берёт 2 карты', () {
      final state = playing(
        one: const Side(hand: ['skellen'], deck: ['footman', 'archer', 'catapult']),
        two: opponent,
      );
      final result = play(state, 'skellen');
      expect(rowCards(result.state, Seat.two, Row.melee), ['skellen']);
      expect(names(result.state.player(Seat.one).hand), ['footman', 'archer']);
      expect(engine.project(result.state, Seat.two).me.score, 9);
      expect(engine.eventsFor(result.events, Seat.two), contains(const CardsDrawnHidden(Seat.one, 2)));
    });

    test('если в колоде меньше двух карт, берёт сколько есть', () {
      final state = playing(
        one: const Side(hand: ['thaler'], deck: ['footman']),
        two: opponent,
      );
      expect(names(play(state, 'thaler').state.player(Seat.one).hand), ['footman']);
    });

    test('в конце раунда шпион уходит в отбой соперника', () {
      final state = playing(
        one: const Side(hand: ['skellen', 'footman']),
        two: const Side(hand: ['archer'], passed: true),
      );
      final played = play(state, 'skellen').state;
      final result = act(engine, played, Seat.one, const Pass());
      expect(names(result.state.player(Seat.two).discard), ['skellen']);
    });
  });

  group('Медик', () {
    test('выбирает обычный отряд из отбоя и разыгрывает его; ход ждёт выбора', () {
      final state = playing(
        one: const Side(hand: ['banner_medic'], discard: ['geralt', 'archer', 'decoy', 'footman']),
        two: opponent,
      );
      final played = play(state, 'banner_medic');
      expect(played.state.turn, Seat.one);
      expect(
        played.state.choice,
        PendingChoice(
          seat: Seat.one,
          kind: ChoiceKind.medicTarget,
          options: [CardOption(instance(state, Seat.one, 'archer')), CardOption(instance(state, Seat.one, 'footman'))],
        ),
      );
      expect(rejected(engine, played.state, Seat.two, const Pass()), RejectReason.choicePending);
      expect(rejected(engine, played.state, Seat.one, const Pass()), RejectReason.choicePending);

      final chosen = act(engine, played.state, Seat.one, ChooseOption(CardOption(instance(state, Seat.one, 'archer'))));
      expect(rowCards(chosen.state, Seat.one, Row.ranged), ['archer']);
      expect(names(chosen.state.player(Seat.one).discard), ['geralt', 'decoy', 'footman']);
      expect(chosen.state.turn, Seat.two);
    });

    test('цепочка Медик → Медик → Шпион выполняется в одном ходу', () {
      final state = playing(
        one: const Side(hand: ['banner_medic'], discard: ['archer_medic', 'skellen'], deck: ['footman', 'archer']),
        two: opponent,
      );
      var result = play(state, 'banner_medic');
      result = act(engine, result.state, Seat.one, ChooseOption(CardOption(instance(state, Seat.one, 'archer_medic'))));
      expect(result.state.choice?.kind, ChoiceKind.medicTarget);
      result = act(engine, result.state, Seat.one, ChooseOption(CardOption(instance(state, Seat.one, 'skellen'))));
      expect(rowCards(result.state, Seat.two, Row.melee), ['skellen']);
      expect(names(result.state.player(Seat.one).hand), ['footman', 'archer']);
      expect(result.state.turn, Seat.two);
    });

    test('без подходящих карт в отбое ничего не происходит', () {
      final state = playing(
        one: const Side(hand: ['banner_medic'], discard: ['geralt']),
        two: opponent,
      );
      final result = play(state, 'banner_medic');
      expect(result.state.choice, isNull);
      expect(result.state.turn, Seat.two);
    });

    test('воскрешённой проворной карте ряд выбирает игрок', () {
      final state = playing(
        one: const Side(hand: ['banner_medic'], discard: ['elf_skirmisher']),
        two: opponent,
      );
      var result = play(state, 'banner_medic');
      result = act(
        engine,
        result.state,
        Seat.one,
        ChooseOption(CardOption(instance(state, Seat.one, 'elf_skirmisher'))),
      );
      expect(result.state.choice?.kind, ChoiceKind.unitRow);
      expect(result.state.choice?.options, const [RowOption(Row.melee), RowOption(Row.ranged)]);
      result = act(engine, result.state, Seat.one, const ChooseOption(RowOption(Row.melee)));
      expect(rowCards(result.state, Seat.one, Row.melee), ['elf_skirmisher']);
    });

    test('при Завоевателе Севера у любого игрока Медик выбирает случайно', () {
      final state = playing(
        one: const Side(hand: ['banner_medic'], discard: ['archer', 'footman']),
        two: const Side(leader: 'emgyr_random_medic', faction: Faction.nilfgaard, hand: ['archer']),
        rng: const ScriptedRng([1]),
      );
      final result = play(state, 'banner_medic');
      expect(result.state.choice, isNull);
      expect(rowCards(result.state, Seat.one, Row.melee), ['footman']);
    });

    test('чужой шпион из своего отбоя ложится на сторону соперника', () {
      final state = playing(
        one: const Side(hand: ['banner_medic'], discard: ['skellen'], deck: ['footman']),
        two: opponent,
      );
      var result = play(state, 'banner_medic');
      result = act(engine, result.state, Seat.one, ChooseOption(CardOption(instance(state, Seat.one, 'skellen'))));
      expect(rowCards(result.state, Seat.two, Row.melee), ['skellen']);
    });
  });

  group('Двойник', () {
    test('выкладывает связанные карты из колоды и руки и называет зону каждой', () {
      final state = playing(
        one: const Side(hand: ['arachas', 'arachas', 'footman'], deck: ['arachas', 'behemoth', 'archer']),
        two: opponent,
      );
      final result = play(state, 'arachas');
      expect(rowCards(result.state, Seat.one, Row.melee), ['arachas', 'arachas', 'arachas']);
      expect(names(result.state.player(Seat.one).hand), ['footman']);
      expect(names(result.state.player(Seat.one).deck), ['behemoth', 'archer']);
      expect(
        result.events.whereType<UnitPlaced>().map((event) => event.source),
        [EntrySource.hand, EntrySource.musterFromDeck, EntrySource.musterFromHand],
      );
    });

    test('призванной проворной карте ряд выбирает игрок, призванный Медик срабатывает', () {
      final state = playing(
        one: const Side(hand: ['nekker'], deck: ['harpy', 'archer_medic'], discard: ['footman']),
        two: opponent,
      );
      var result = play(state, 'nekker');
      expect(result.state.choice?.kind, ChoiceKind.unitRow);
      expect(result.state.choice?.subject, instance(state, Seat.one, 'harpy'));
      result = act(engine, result.state, Seat.one, const ChooseOption(RowOption(Row.ranged)));
      expect(result.state.choice?.kind, ChoiceKind.medicTarget);
      result = act(engine, result.state, Seat.one, ChooseOption(CardOption(instance(state, Seat.one, 'footman'))));
      expect(rowCards(result.state, Seat.one, Row.melee), ['nekker', 'footman']);
      expect(rowCards(result.state, Seat.one, Row.ranged), ['harpy', 'archer_medic']);
      expect(result.state.turn, Seat.two);
    });

    test('связь несимметрична: Огромный главоглаз призывает Главоглазов, но не наоборот', () {
      final state = playing(
        one: const Side(hand: ['behemoth'], deck: ['arachas', 'arachas']),
        two: opponent,
      );
      final result = play(state, 'behemoth');
      expect(rowCards(result.state, Seat.one, Row.melee), ['arachas', 'arachas']);

      final reverse = playing(
        one: const Side(hand: ['arachas'], deck: ['behemoth']),
        two: opponent,
      );
      expect(rowCards(play(reverse, 'arachas').state, Seat.one, Row.siege), isEmpty);
    });

    test('Керис призывает Воительниц клана Друммонд', () {
      final state = playing(
        one: const Side(hand: ['cerys', 'drummond'], deck: ['drummond']),
        two: opponent,
      );
      final result = play(state, 'cerys');
      expect(rowCards(result.state, Seat.one, Row.melee), ['cerys', 'drummond', 'drummond']);
    });
  });

  group('Казнь', () {
    test('уничтожает сильнейшие обычные отряды у обоих, героев не трогает', () {
      final state = playing(
        one: const Side(hand: ['scorch'], melee: ['vesemir', 'geralt', 'footman']),
        two: const Side(hand: ['archer'], melee: ['vesemir'], ranged: ['archer']),
      );
      final result = play(state, 'scorch');
      expect(rowCards(result.state, Seat.one, Row.melee), ['geralt', 'footman']);
      expect(rowCards(result.state, Seat.two, Row.melee), isEmpty);
      expect(names(result.state.player(Seat.one).discard), ['vesemir', 'scorch']);
      expect(names(result.state.player(Seat.two).discard), ['vesemir']);
    });

    test('сильнейший считается по текущей силе', () {
      final state = playing(
        one: const Side(hand: ['scorch'], melee: ['vesemir']),
        two: const Side(hand: ['archer'], siege: ['catapult']),
        weather: [('rain', Seat.two)],
      );
      final result = play(state, 'scorch');
      expect(rowCards(result.state, Seat.one, Row.melee), isEmpty);
      expect(rowCards(result.state, Seat.two, Row.siege), ['catapult']);
    });

    test('если наибольшая сила 0, уничтожаются все обычные отряды с силой 0', () {
      final state = playing(
        one: const Side(hand: ['scorch'], ranged: ['cow'], melee: ['geralt']),
        two: opponent,
      );
      final result = play(state, 'scorch');
      expect(names(result.state.player(Seat.one).discard), ['cow', 'scorch']);
      expect(rowCards(result.state, Seat.one, Row.melee), ['geralt', 'bovine']);
    });

    test('без обычных отрядов ничего не происходит', () {
      final state = playing(
        one: const Side(hand: ['scorch'], melee: ['geralt']),
        two: opponent,
      );
      final result = play(state, 'scorch');
      expect(result.events.whereType<UnitsDestroyed>(), isEmpty);
    });

    test('Казнь по ряду учитывает героев в пороге 10', () {
      final state = playing(
        one: const Side(hand: ['villentretenmerth']),
        two: const Side(hand: ['archer'], melee: ['geralt', 'footman', 'ghoul']),
      );
      final result = play(state, 'villentretenmerth');
      expect(rowCards(result.state, Seat.two, Row.melee), ['geralt', 'ghoul']);
    });

    test('Казнь по ряду не срабатывает, если сила ряда меньше 10', () {
      final state = playing(
        one: const Side(hand: ['schirru']),
        two: const Side(hand: ['archer'], siege: ['catapult']),
      );
      expect(rowCards(play(state, 'schirru').state, Seat.two, Row.siege), ['catapult']);
    });

    test('Пират из клана Димун может уничтожить себя', () {
      final state = playing(
        one: const Side(hand: ['pirate']),
        two: const Side(hand: ['archer'], melee: ['footman']),
      );
      final result = play(state, 'pirate');
      expect(rowCards(result.state, Seat.one, Row.ranged), isEmpty);
      expect(names(result.state.player(Seat.one).discard), ['pirate']);
      expect(rowCards(result.state, Seat.two, Row.melee), ['footman']);
    });
  });

  group('Приманка', () {
    test('уничтоженная Камби сразу призывает Хеймдалля на своё место', () {
      final state = playing(
        one: const Side(hand: ['scorch'], melee: ['footman', 'kambi', 'vesemir']),
        two: opponent,
      );
      // Весемир сильнее, поэтому сначала Казнь не трогает Камби.
      final first = play(state, 'scorch');
      expect(rowCards(first.state, Seat.one, Row.melee), ['footman', 'kambi']);

      final zero = playing(
        one: const Side(hand: ['scorch'], melee: ['geralt', 'kambi', 'geralt']),
        two: opponent,
      );
      final result = play(zero, 'scorch');
      expect(rowCards(result.state, Seat.one, Row.melee), ['geralt', 'heimdall', 'geralt']);
      expect(names(result.state.player(Seat.one).discard), ['kambi', 'scorch']);
    });

    test('Чучело на Приманке призыва не вызывает', () {
      final state = playing(
        one: const Side(hand: ['decoy'], ranged: ['cow']),
        two: opponent,
      );
      final result = play(state, 'decoy', target: 'cow');
      expect(rowCards(result.state, Seat.one, Row.ranged), ['decoy']);
      expect(rowCards(result.state, Seat.one, Row.melee), isEmpty);
      expect(names(result.state.player(Seat.one).hand), ['cow']);
    });
  });

  group('Берсерк и Мардрём', () {
    test('Мардрём превращает Берсерков своего ряда, а позже пришедший превращается сразу', () {
      final state = playing(
        one: const Side(hand: ['mardrem', 'berserk'], melee: ['berserk']),
        two: opponent,
      );
      final result = play(state, 'mardrem', row: Row.melee);
      expect(rowCards(result.state, Seat.one, Row.melee), ['vildkaarl']);
      expect(result.state.player(Seat.one).rows[Row.melee]!.cards.single.beneath?.cardId, const CardId('berserk'));
    });

    test('Мышовур в ряду — Мардрём для этого ряда', () {
      final state = playing(
        one: const Side(hand: ['young_berserk'], ranged: ['mysovur']),
        two: opponent,
      );
      final result = play(state, 'young_berserk');
      expect(rowCards(result.state, Seat.one, Row.ranged), ['mysovur', 'young_vildkaarl']);
    });

    test('Мардрём в другом ряду Берсерка не превращает', () {
      final state = playing(
        one: const Side(hand: ['mardrem'], melee: ['berserk']),
        two: opponent,
      );
      expect(rowCards(play(state, 'mardrem', row: Row.siege).state, Seat.one, Row.melee), ['berserk']);
    });

    test('уничтоженный вильдкаарл выходит из игры, Берсерк уходит в отбой', () {
      final state = playing(
        one: const Side(hand: ['berserk', 'scorch'], slots: {Row.melee: 'mardrem'}),
        two: opponent,
      );
      final transformed = play(state, 'berserk').state;
      final skip = act(engine, transformed, Seat.two, PlayCard(find(transformed, Seat.two, 'archer'))).state;
      final result = play(skip, 'scorch');
      expect(rowCards(result.state, Seat.one, Row.melee), isEmpty);
      expect(names(result.state.player(Seat.one).discard), ['berserk', 'scorch']);
      expect(result.events.whereType<CardLeftGame>().single.card.cardId, const CardId('vildkaarl'));
    });

    test('Чучело на вильдкаарле: вильдкаарл в руку, Берсерк в отбой', () {
      final state = playing(
        one: const Side(hand: ['berserk', 'decoy'], slots: {Row.melee: 'mardrem'}),
        two: opponent,
      );
      final transformed = play(state, 'berserk').state;
      final vildkaarl = transformed.player(Seat.one).rows[Row.melee]!.cards.single.card;
      final skip = act(engine, transformed, Seat.two, PlayCard(find(transformed, Seat.two, 'archer'))).state;
      final result = act(engine, skip, Seat.one, PlayCard(find(skip, Seat.one, 'decoy'), target: vildkaarl.id));
      expect(names(result.state.player(Seat.one).hand), ['vildkaarl']);
      expect(names(result.state.player(Seat.one).discard), ['berserk']);
    });
  });

  group('Чучело', () {
    test('возвращает обычный отряд в руку и встаёт на его место с силой 0', () {
      final state = playing(
        one: const Side(hand: ['decoy'], melee: ['footman', 'vesemir']),
        two: opponent,
      );
      final result = play(state, 'decoy', target: 'footman');
      expect(rowCards(result.state, Seat.one, Row.melee), ['decoy', 'vesemir']);
      expect(names(result.state.player(Seat.one).hand), ['footman']);
      expect(engine.project(result.state, Seat.one).me.rows[Row.melee]!.cards.first.strength, 0);
    });

    test('может забрать шпиона соперника со своей стороны', () {
      final state = playing(
        one: const Side(hand: ['decoy'], melee: ['skellen']),
        two: opponent,
      );
      final result = play(state, 'decoy', target: 'skellen');
      expect(names(result.state.player(Seat.one).hand), ['skellen']);
    });

    test('нельзя выбрать героя, чужую карту или без цели', () {
      final state = playing(
        one: const Side(hand: ['decoy'], melee: ['geralt', 'footman']),
        two: const Side(hand: ['archer'], melee: ['vesemir']),
      );
      final decoy = find(state, Seat.one, 'decoy');
      expect(rejected(engine, state, Seat.one, PlayCard(decoy)), RejectReason.targetRequired);
      expect(
        rejected(engine, state, Seat.one, PlayCard(decoy, target: find(state, Seat.one, 'geralt'))),
        RejectReason.invalidTarget,
      );
      expect(
        rejected(engine, state, Seat.one, PlayCard(decoy, target: find(state, Seat.two, 'vesemir'))),
        RejectReason.invalidTarget,
      );

      final empty = playing(
        one: const Side(hand: ['decoy', 'footman'], melee: ['geralt']),
        two: opponent,
      );
      expect(rejected(engine, empty, Seat.one, PlayCard(find(empty, Seat.one, 'decoy'))), RejectReason.noValidTarget);
    });

    test('при повторном розыгрыше способность при выходе срабатывает снова', () {
      final state = playing(
        one: const Side(hand: ['decoy'], melee: ['skellen'], deck: ['footman', 'archer']),
        two: opponent,
      );
      final decoyed = play(state, 'decoy', target: 'skellen').state;
      final skip = act(engine, decoyed, Seat.two, PlayCard(find(decoyed, Seat.two, 'archer'))).state;
      final result = act(engine, skip, Seat.one, PlayCard(find(skip, Seat.one, 'skellen')));
      expect(rowCards(result.state, Seat.two, Row.melee), ['skellen']);
      expect(names(result.state.player(Seat.one).hand), ['footman', 'archer']);
    });
  });

  group('погода', () {
    test('погода действует на ряд обоих игроков', () {
      final state = playing(
        one: const Side(hand: ['frost'], melee: ['vesemir']),
        two: const Side(hand: ['archer'], melee: ['vesemir']),
      );
      final result = play(state, 'frost');
      expect(engine.project(result.state, Seat.one).me.rows[Row.melee]!.strength, 1);
      expect(engine.project(result.state, Seat.one).opponent.rows[Row.melee]!.strength, 1);
      expect(engine.project(result.state, Seat.one).me.rows[Row.melee]!.weather, isTrue);
    });

    test('повторная карта того же вида сразу уходит в отбой хозяина', () {
      final state = playing(
        one: const Side(hand: ['frost']),
        two: opponent,
        weather: [('frost', Seat.two)],
      );
      final result = play(state, 'frost');
      expect(result.state.weather, hasLength(1));
      expect(names(result.state.player(Seat.one).discard), ['frost']);
    });

    test('Шторм кладётся, даже если Мгла уже лежит', () {
      final state = playing(
        one: const Side(hand: ['storm']),
        two: opponent,
        weather: [('fog', Seat.two)],
      );
      expect(names([for (final weather in play(state, 'storm').state.weather) weather.card]), ['fog', 'storm']);
    });

    test('Ясное небо: вся погода и само Ясное небо уходят в отбой хозяев', () {
      final state = playing(
        one: const Side(hand: ['clear']),
        two: opponent,
        weather: [('fog', Seat.two), ('frost', Seat.one)],
      );
      final result = play(state, 'clear');
      expect(result.state.weather, isEmpty);
      expect(names(result.state.player(Seat.one).discard), ['frost', 'clear']);
      expect(names(result.state.player(Seat.two).discard), ['fog']);
    });
  });

  test('рог в ряду с Лютиком класть можно', () {
    final state = playing(
      one: const Side(hand: ['horn'], melee: ['dandelion', 'vesemir']),
      two: opponent,
    );
    final result = play(state, 'horn', row: Row.melee);
    expect(
      [for (final card in engine.project(result.state, Seat.one).me.rows[Row.melee]!.cards) card.strength],
      [4, 12],
    );
  });
}
