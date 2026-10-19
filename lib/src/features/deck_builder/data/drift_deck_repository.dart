import 'package:drift/drift.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';

/// Колоды в базе Drift: строка в `decks`, по строке на карту в `deck_cards` и выбор активных колод в `active_decks`.
final class DriftDeckRepository implements DeckRepository {
  /// Создаёт репозиторий над [database].
  const DriftDeckRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Deck>> watchAll() => _decksWithCards().watch().map(_toDecks);

  @override
  Future<List<Deck>> findByFaction(String factionId) async {
    final query = _decksWithCards()..where(_db.decks.factionId.equals(factionId));
    return _toDecks(await query.get());
  }

  @override
  Future<Deck?> findById(String id) async {
    final query = _decksWithCards()..where(_db.decks.id.equals(id));
    final decks = _toDecks(await query.get());
    return decks.isEmpty ? null : decks.single;
  }

  @override
  Future<void> save(Deck deck, {bool activate = false}) => _db.transaction(() async {
    await _db
        .into(_db.decks)
        .insertOnConflictUpdate(
          DecksCompanion.insert(
            id: deck.id,
            name: deck.name,
            factionId: deck.factionId,
            leaderId: deck.leaderId,
            // Сортировка идёт по тексту ISO-8601 и верна, только если все моменты записаны в UTC.
            updatedAt: deck.updatedAt.toUtc(),
          ),
        );
    await (_db.delete(_db.deckCards)..where((card) => card.deckId.equals(deck.id))).go();
    // Колода сменила фракцию: активной колодой прежней фракции она больше быть не может.
    await (_db.delete(
      _db.activeDecks,
    )..where((active) => active.deckId.equals(deck.id) & active.factionId.equals(deck.factionId).not())).go();
    await _db.batch((batch) {
      batch.insertAll(_db.deckCards, [
        for (final MapEntry(key: cardId, value: copies) in deck.cards.entries)
          DeckCardsCompanion.insert(deckId: deck.id, cardId: cardId, copies: copies),
      ]);
    });
    if (activate) await _activate(factionId: deck.factionId, deckId: deck.id);
  });

  @override
  Future<void> delete(String id) => (_db.delete(_db.decks)..where((deck) => deck.id.equals(id))).go();

  @override
  Stream<Map<String, String>> watchActiveDeckIds() =>
      _db.select(_db.activeDecks).watch().map((rows) => {for (final row in rows) row.factionId: row.deckId});

  @override
  Future<String?> findActiveDeckId(String factionId) async {
    final query = _db.select(_db.activeDecks)..where((active) => active.factionId.equals(factionId));
    return (await query.getSingleOrNull())?.deckId;
  }

  @override
  Future<void> setActive(String deckId) => _db.transaction(() async {
    // Фракция берётся из базы в той же транзакции: колоду могли пересохранить с другой фракцией.
    final query = _db.selectOnly(_db.decks)
      ..addColumns([_db.decks.factionId])
      ..where(_db.decks.id.equals(deckId));
    final factionId = (await query.getSingleOrNull())?.read(_db.decks.factionId);
    if (factionId == null) throw DeckNotFoundException(deckId);
    await _activate(factionId: factionId, deckId: deckId);
  });

  Future<void> _activate({required String factionId, required String deckId}) => _db
      .into(_db.activeDecks)
      .insertOnConflictUpdate(ActiveDecksCompanion.insert(factionId: factionId, deckId: deckId));

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
