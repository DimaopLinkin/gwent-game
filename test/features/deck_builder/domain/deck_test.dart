import 'package:flutter_test/flutter_test.dart';

import '../../../support/factories.dart';

void main() {
  test('число карт считает копии', () {
    expect(testDeck(cards: {'a': 3, 'b': 1}).cardCount, 4);
  });

  test('колоды с одинаковыми полями равны', () {
    expect(testDeck(cards: {'a': 1, 'b': 2}), testDeck(cards: {'b': 2, 'a': 1}));
    expect(testDeck(cards: {'a': 1}), isNot(testDeck(cards: {'a': 2})));
  });

  test('состав колоды нельзя изменить снаружи', () {
    final source = {'a': 1};
    final deck = testDeck(cards: source);
    source['b'] = 1;

    expect(deck.cards, {'a': 1});
    expect(() => deck.cards['c'] = 1, throwsUnsupportedError);
  });

  test('копия меняет только переданные поля', () {
    final deck = testDeck();
    final renamed = deck.copyWith(name: 'Новая');

    expect(renamed.name, 'Новая');
    expect(renamed.copyWith(name: deck.name), deck);
  });

  test('ноль копий карты недопустим', () {
    expect(() => testDeck(cards: {'a': 0}), throwsA(isA<AssertionError>()));
  });
}
