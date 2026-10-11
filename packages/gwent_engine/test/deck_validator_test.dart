import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Разделы 2.1 и 2.2 правил: сборка колоды.
void main() {
  final validator = DeckValidator(catalog, const GameRules());

  Deck deck(String leader, Map<String, int> cards) => Deck(
    leader: LeaderId(leader),
    cards: [
      for (final MapEntry(key: card, value: count) in cards.entries)
        for (var i = 0; i < count; i++) CardId(card),
    ],
  );

  /// 22 отряда Королевств Севера и нейтральных: годная основа колоды.
  const units = {'footman': 10, 'archer': 10, 'catapult': 2};

  test('колода из 22 отрядов и 10 специальных карт годится', () {
    expect(
      validator.validate(deck('foltest_clear', {...units, 'frost': 3, 'horn': 3, 'decoy': 3, 'scorch': 1})),
      isEmpty,
    );
  });

  test('отрядов меньше 22, специальных больше 10', () {
    expect(
      validator.validate(deck('foltest_clear', {'footman': 10, 'frost': 3, 'fog': 3, 'rain': 3, 'clear': 2})),
      const [
        TooFewUnitCards(count: 10, min: 22),
        TooManySpecialCards(count: 11, max: 10),
      ],
    );
  });

  test('копий больше, чем существует в игре', () {
    expect(validator.validate(deck('foltest_clear', {...units, 'horn': 4})), [
      const TooManyCopies(CardId('horn'), count: 4, max: 3),
    ]);
  });

  test('карты чужой фракции, созданные и неизвестные карты не допускаются', () {
    expect(validator.validate(deck('foltest_clear', {...units, 'arachas': 1, 'vildkaarl': 1, 'nonexistent': 1})), [
      const WrongFaction(CardId('arachas')),
      const WrongFaction(CardId('vildkaarl')),
      const CreatedCardInDeck(CardId('vildkaarl')),
      const UnknownCard(CardId('nonexistent')),
    ]);
  });

  test('Мардрём доступен только колоде Скеллиге', () {
    expect(validator.validate(deck('foltest_clear', {...units, 'mardrem': 1})), [
      const WrongFaction(CardId('mardrem')),
    ]);
    expect(
      validator.validate(deck('bran', {...units, 'mardrem': 1})),
      isNot(contains(const WrongFaction(CardId('mardrem')))),
    );
  });

  test('неизвестный лидер', () {
    expect(validator.validate(deck('nobody', units)), [const UnknownLeader(LeaderId('nobody'))]);
  });
}
