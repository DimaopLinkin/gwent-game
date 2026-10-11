import 'package:gwent_engine/src/cards/card_catalog.dart';
import 'package:gwent_engine/src/cards/card_definition.dart';
import 'package:gwent_engine/src/cards/deck.dart';
import 'package:gwent_engine/src/cards/faction.dart';
import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/rules/deck_violation.dart';
import 'package:gwent_engine/src/rules/game_rules.dart';

/// Проверка колоды по правилам сборки (разделы 2.1 и 2.2). Ею пользуются конструктор колоды и хост партии.
final class DeckValidator {
  const DeckValidator(this._catalog, this._rules);

  final CardCatalog _catalog;
  final GameRules _rules;

  /// Все нарушения колоды; пустой список значит, что колода годится.
  List<DeckViolation> validate(Deck deck) {
    final violations = <DeckViolation>[];
    final leader = _catalog.leader(deck.leader);
    if (leader == null) {
      violations.add(UnknownLeader(deck.leader));
    } else if (!leader.faction.isDeckFaction) {
      violations.add(LeaderNotDeckFaction(deck.leader));
    }

    final copies = <CardId, int>{};
    var units = 0;
    var specials = 0;
    for (final id in deck.cards) {
      copies[id] = (copies[id] ?? 0) + 1;
    }
    for (final MapEntry(key: id, value: count) in copies.entries) {
      final card = _catalog.card(id);
      if (card == null) {
        violations.add(UnknownCard(id));
        continue;
      }
      if (leader != null && card.faction != Faction.neutral && card.faction != leader.faction) {
        violations.add(WrongFaction(id));
      }
      if (card.copies == 0) {
        violations.add(CreatedCardInDeck(id));
      } else if (count > card.copies) {
        violations.add(TooManyCopies(id, count: count, max: card.copies));
      }
      switch (card) {
        case UnitCardDefinition():
          units += count;
        case SpecialCardDefinition():
          specials += count;
      }
    }

    if (units < _rules.minUnitCards) {
      violations.add(TooFewUnitCards(count: units, min: _rules.minUnitCards));
    }
    if (specials > _rules.maxSpecialCards) {
      violations.add(TooManySpecialCards(count: specials, max: _rules.maxSpecialCards));
    }
    return violations;
  }
}
