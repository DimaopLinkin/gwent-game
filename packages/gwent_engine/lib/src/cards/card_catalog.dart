import 'package:gwent_engine/src/cards/card_definition.dart';
import 'package:gwent_engine/src/cards/ids.dart';

/// Справочник карт, по которому движок считает партию. Его строит пакет контента.
abstract interface class CardCatalog {
  /// Определение карты или `null`, если карты нет в справочнике.
  CardDefinition? card(CardId id);

  /// Определение лидера или `null`, если лидера нет в справочнике.
  LeaderDefinition? leader(LeaderId id);
}

/// Справочник в памяти: для пакета контента после разбора и для тестов.
final class InMemoryCardCatalog implements CardCatalog {
  InMemoryCardCatalog({required Iterable<CardDefinition> cards, Iterable<LeaderDefinition> leaders = const []})
    : _cards = {for (final card in cards) card.id: card},
      _leaders = {for (final leader in leaders) leader.id: leader};

  final Map<CardId, CardDefinition> _cards;
  final Map<LeaderId, LeaderDefinition> _leaders;

  @override
  CardDefinition? card(CardId id) => _cards[id];

  @override
  LeaderDefinition? leader(LeaderId id) => _leaders[id];
}
