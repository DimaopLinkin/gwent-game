import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../support/factories.dart';

void main() {
  test('лидер и по элементу на копию, карты по возрастанию UUID', () {
    final deck = testDeck(cards: const {'b': 2, 'c': 1, 'a': 1});

    expect(
      deck.toEngineDeck(),
      Deck(leader: LeaderId(deck.leaderId), cards: const [CardId('a'), CardId('b'), CardId('b'), CardId('c')]),
    );
  });

  test('порядок вставки карт в колоду не меняет результат', () {
    expect(
      testDeck(cards: const {'a': 1, 'b': 2}).toEngineDeck(),
      testDeck(cards: const {'b': 2, 'a': 1}).toEngineDeck(),
    );
  });
}
