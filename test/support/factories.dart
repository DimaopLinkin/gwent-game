import 'package:gwent/src/features/deck_builder/domain/deck.dart';

/// Колода для тестов. UUID условные: проверку состава по пакету контента делает движок.
Deck testDeck({
  String id = 'deck-1',
  String name = 'Скеллиге',
  String factionId = 'faction-skellige',
  Map<String, int> cards = const {'card-a': 2, 'card-b': 1},
  DateTime? updatedAt,
}) => Deck(
  id: id,
  name: name,
  factionId: factionId,
  leaderId: 'leader-crach',
  cards: cards,
  updatedAt: updatedAt ?? DateTime.utc(2026, 10, 11, 12),
);
