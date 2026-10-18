import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../support/deck_rules_fixtures.dart';

void main() {
  final rules = smallDeckRules;
  final updatedAt = DateTime.utc(2026, 10, 12);

  group('проверка колоды', () {
    test('годная колода без проблем', () {
      expect(rules.check(smallSkelligeDeck()), isEmpty);
    });

    test('мало отрядов', () {
      final deck = smallSkelligeDeck(cards: const {Small.warrior: 3, Small.cerys: 1});

      expect(rules.check(deck), [const DeckRuleViolation(TooFewUnitCards(count: 4, min: 5))]);
    });

    test('много специальных карт', () {
      final deck = smallSkelligeDeck(
        cards: const {Small.warrior: 3, Small.cerys: 1, Small.geralt: 1, Small.frost: 2, Small.horn: 1},
      );

      expect(rules.check(deck), [const DeckRuleViolation(TooManySpecialCards(count: 3, max: 2))]);
    });

    test('карта чужой фракции, созданная карта, лишняя копия и неизвестная карта', () {
      final deck = smallSkelligeDeck(
        cards: const {Small.warrior: 3, Small.cerys: 2, Small.ghoul: 1, Small.vildkaarl: 1, 'нет такой': 1},
      );

      expect(
        rules.check(deck),
        unorderedEquals([
          const DeckRuleViolation(TooManyCopies(CardId(Small.cerys), count: 2, max: 1)),
          const DeckRuleViolation(WrongFaction(CardId(Small.ghoul))),
          const DeckRuleViolation(CreatedCardInDeck(CardId(Small.vildkaarl))),
          const DeckRuleViolation(UnknownCard(CardId('нет такой'))),
        ]),
      );
    });

    test('неизвестный лидер', () {
      expect(rules.check(smallSkelligeDeck(leaderId: 'нет такого')), [
        const DeckRuleViolation(UnknownLeader(LeaderId('нет такого'))),
      ]);
    });

    test('лидер другой фракции, чем у колоды', () {
      final deck = smallSkelligeDeck(leaderId: Small.eredin, cards: const {Small.ghoul: 3, Small.vesemir: 2});

      expect(rules.check(deck), [const LeaderOfOtherFaction(leaderId: Small.eredin, leaderFactionId: Small.monsters)]);
    });
  });

  test('фракции с колодой в порядке пакета', () {
    expect([for (final faction in rules.deckFactions) faction.id], [Small.skellige, Small.monsters]);
    expect(rules.isDeckFaction(Small.skellige), isTrue);
    expect(rules.isDeckFaction(Small.common), isFalse);
    expect(rules.isDeckFaction('нет такой'), isFalse);
  });

  group('стартовая колода', () {
    test('все отряды фракции и нейтральные, по копии специальных карт фракции, затем нейтральных', () {
      final deck = rules.starterDeck(Small.skellige, id: 'starter', updatedAt: updatedAt);

      expect(deck.id, 'starter');
      expect(deck.name, 'Скеллиге');
      expect(deck.factionId, Small.skellige);
      expect(deck.leaderId, Small.crach);
      expect(deck.updatedAt, updatedAt);
      expect(deck.cards, {
        Small.warrior: 3,
        Small.cerys: 1,
        Small.geralt: 1,
        Small.vesemir: 2,
        Small.mardroeme: 1,
        Small.frost: 1,
      });
      expect(rules.check(deck), isEmpty);
    });

    test('нейтральные отряды входят в колоду, даже когда отрядов фракции хватает на минимум', () {
      final deck = rules.starterDeck(Small.monsters, id: 'starter', updatedAt: updatedAt);

      expect(deck.leaderId, Small.eredin);
      expect(deck.cards, {Small.ghoul: 3, Small.geralt: 1, Small.vesemir: 2, Small.frost: 1, Small.horn: 1});
      expect(rules.check(deck), isEmpty);
    });

    test('из нейтральной или неизвестной фракции колоду не собрать', () {
      for (final factionId in [Small.common, 'нет такой']) {
        expect(
          () => rules.starterDeck(factionId, id: 'starter', updatedAt: updatedAt),
          throwsA(isA<NotADeckFactionException>().having((e) => e.factionId, 'factionId', factionId)),
        );
      }
    });
  });
}
