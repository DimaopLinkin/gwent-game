import 'package:drift/drift.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';

/// Колоды в базе Drift: строка в `decks` и по строке на карту в `deck_cards`.
final class DriftDeckRepository implements DeckRepository {
  /// Создаёт репозиторий над [database].
  const DriftDeckRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Deck>> watchAll() => _decksWithCards().watch().map(_toDecks);

  @override
  Future<Deck?> findById(String id) async {
    final query = _decksWithCards()..where(_db.decks.id.equals(id));
    final decks = _toDecks(await query.get());
    return decks.isEmpty ? null : decks.single;
  }

  @override
  Future<void> save(Deck deck) => _db.transaction(() async {
    await _db
        .into(_db.decks)
        .insertOnConflictUpdate(
          DecksCompanion.insert(
            id: deck.id,
            name: deck.name,
            factionId: deck.factionId,
            leaderId: deck.leaderId,
            updatedAt: deck.updatedAt,
          ),
        );
    await (_db.delete(_db.deckCards)..where((card) => card.deckId.equals(deck.id))).go();
    await _db.batch((batch) {
      batch.insertAll(_db.deckCards, [
        for (final MapEntry(key: cardId, value: copies) in deck.cards.entries)
          DeckCardsCompanion.insert(deckId: deck.id, cardId: cardId, copies: copies),
      ]);
    });
  });

  @override
  Future<void> delete(String id) => (_db.delete(_db.decks)..where((deck) => deck.id.equals(id))).go();

  /// Колоды со всеми картами одним запросом: поток следит за обеими таблицами.
  JoinedSelectStatement<HasResultSet, dynamic> _decksWithCards() =>
      _db.select(_db.decks).join([leftOuterJoin(_db.deckCards, _db.deckCards.deckId.equalsExp(_db.decks.id))])
        ..orderBy([OrderingTerm.desc(_db.decks.updatedAt), OrderingTerm.asc(_db.decks.id)]);

  /// Склеивает строки соединения в колоды, сохраняя порядок запроса.
  List<Deck> _toDecks(List<TypedResult> rows) {
    final decks = <String, DeckRow>{};
    final cards = <String, Map<String, int>>{};
    for (final row in rows) {
      final deck = row.readTable(_db.decks);
      decks.putIfAbsent(deck.id, () => deck);
      final deckCards = cards.putIfAbsent(deck.id, () => {});
      final card = row.readTableOrNull(_db.deckCards);
      if (card != null) deckCards[card.cardId] = card.copies;
    }
    return [
      for (final deck in decks.values)
        Deck(
          id: deck.id,
          name: deck.name,
          factionId: deck.factionId,
          leaderId: deck.leaderId,
          cards: cards[deck.id]!,
          updatedAt: deck.updatedAt,
        ),
    ];
  }
}
