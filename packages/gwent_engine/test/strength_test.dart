import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/match_builder.dart';

/// Раздел 8 правил: расчёт силы и контрольные примеры.
void main() {
  List<int> strengths(MatchState state, Seat seat, Row row) => [
    for (final card in engine.project(state, seat).me.rows[row]!.cards) card.strength,
  ];

  int rowStrength(MatchState state, Seat seat, Row row) => engine.project(state, seat).me.rows[row]!.strength;

  group('контрольные примеры раздела 8', () {
    test('пример пользователя: 2 Прочной связи и Прилив сил под погодой с рогом дают 8 каждой', () {
      final state = playing(
        one: const Side(melee: ['blue_stripes', 'blue_stripes', 'olaf'], slots: {Row.melee: 'horn'}),
        weather: [('frost', Seat.two)],
      );
      expect(strengths(state, Seat.one, Row.melee), [8, 8, 2]);
    });

    test('3 Бойца Синих Полосок под Морозом с рогом: каждый 6, ряд 18', () {
      final state = playing(
        one: const Side(melee: ['blue_stripes', 'blue_stripes', 'blue_stripes'], slots: {Row.melee: 'horn'}),
        weather: [('frost', Seat.one)],
      );
      expect(strengths(state, Seat.one, Row.melee), [6, 6, 6]);
      expect(rowStrength(state, Seat.one, Row.melee), 18);
    });

    test('3 Каэдвенских осадных мастера с рогом: каждый 6, ряд 18', () {
      final state = playing(
        one: const Side(siege: ['kaedwen_siege', 'kaedwen_siege', 'kaedwen_siege'], slots: {Row.siege: 'horn'}),
      );
      expect(strengths(state, Seat.one, Row.siege), [6, 6, 6]);
      expect(rowStrength(state, Seat.one, Row.siege), 18);
    });

    test('Прилив сил добавляется до Прочной связи, связь до рога: ((8 + 3) · 2) · 2 = 44', () {
      final state = playing(
        one: const Side(
          siege: ['bond_catapult', 'bond_catapult', 'kaedwen_siege', 'kaedwen_siege', 'kaedwen_siege'],
          slots: {Row.siege: 'horn'},
        ),
      );
      expect(strengths(state, Seat.one, Row.siege), [44, 44, 6, 6, 6]);
    });

    test('Лютик не удваивает себя, а спецкарта рога удваивает и его', () {
      final without = playing(one: const Side(melee: ['dandelion', 'vesemir']));
      expect(strengths(without, Seat.one, Row.melee), [2, 12]);

      final withHorn = playing(
        one: const Side(melee: ['dandelion', 'vesemir'], slots: {Row.melee: 'horn'}),
      );
      expect(strengths(withHorn, Seat.one, Row.melee), [4, 12]);
    });

    test('Обратившийся вильдкаарл, Удальрик и Керис: 14, 5, 10', () {
      final state = playing(one: const Side(melee: ['vildkaarl', 'udalryk', 'cerys']));
      expect(strengths(state, Seat.one, Row.melee), [14, 5, 10]);
    });

    test('Вероломный: герой-шпион остаётся 0, шпион под Морозом даёт 2', () {
      final state = playing(
        one: const Side(leader: 'eredin_spies', faction: Faction.monsters),
        two: const Side(melee: ['mysterious_elf', 'skellen']),
        weather: [('frost', Seat.one)],
      );
      expect(strengths(state, Seat.two, Row.melee), [0, 2]);
    });
  });

  group('шаги расчёта', () {
    test('погода снижает обычные отряды до 1, силу 0 оставляет 0, героев не трогает', () {
      final state = playing(
        one: const Side(melee: ['vesemir', 'cow', 'geralt']),
        weather: [('frost', Seat.two)],
      );
      // Корова лежит в дальнем ряду по данным, но сборщик кладёт её туда, куда сказано: важна только сила 0.
      expect(strengths(state, Seat.one, Row.melee), [1, 0, 15]);
    });

    test('Король Бран: погода на его стороне делит силу пополам, но не ниже 1', () {
      final state = playing(
        one: const Side(leader: 'bran', faction: Faction.skellige, melee: ['udalryk', 'vesemir', 'ghoul', 'cow']),
        two: const Side(melee: ['vesemir']),
        weather: [('frost', Seat.two)],
      );
      expect(strengths(state, Seat.one, Row.melee), [2, 3, 1, 0]);
      expect(strengths(state, Seat.two, Row.melee), [1]);
    });

    test('без Вероломного шпион считается как обычный отряд', () {
      final state = playing(two: const Side(melee: ['skellen']));
      expect(strengths(state, Seat.two, Row.melee), [9]);
    });

    test('несколько источников рога дают одно удвоение', () {
      final state = playing(
        one: const Side(melee: ['dandelion', 'vesemir'], slots: {Row.melee: 'leader_horn'}),
      );
      expect(strengths(state, Seat.one, Row.melee), [4, 12]);
    });

    test('Мардрём в слоте рога силу не удваивает', () {
      final state = playing(
        one: const Side(melee: ['vesemir'], slots: {Row.melee: 'mardrem'}),
      );
      expect(strengths(state, Seat.one, Row.melee), [6]);
    });

    test('Прочная связь считает только карты того же определения в том же ряду', () {
      final state = playing(one: const Side(melee: ['blue_stripes', 'blue_stripes', 'poor_infantry']));
      expect(strengths(state, Seat.one, Row.melee), [8, 8, 1]);
    });

    test('герой с Приливом сил даёт +1 другим, сам не получает', () {
      final state = playing(one: const Side(melee: ['kejran', 'vesemir', 'olaf']));
      expect(strengths(state, Seat.one, Row.melee), [8, 8, 13]);
    });

    test('очки стороны: сумма трёх рядов, включая героев', () {
      final state = playing(
        one: const Side(melee: ['geralt'], ranged: ['archer'], siege: ['catapult']),
      );
      expect(engine.project(state, Seat.one).me.score, 26);
    });
  });
}
