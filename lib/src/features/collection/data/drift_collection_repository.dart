import 'package:drift/drift.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/collection/domain/collection_repository.dart';
import 'package:gwent/src/features/collection/domain/owned_cards.dart';

/// Открытые карты в таблице `owned_cards` базы Drift: по строке на карту или лидера.
final class DriftCollectionRepository implements CollectionRepository {
  /// Создаёт репозиторий над [database].
  const DriftCollectionRepository(this._db);

  final AppDatabase _db;

  @override
  Future<CardCollection> load() async => _toCollection(await _db.select(_db.ownedCardEntries).get());

  @override
  Stream<CardCollection> watch() => _db.select(_db.ownedCardEntries).watch().map(_toCollection);

  @override
  Future<void> grant(Map<String, int> copies) async {
    for (final MapEntry(key: cardId, value: count) in copies.entries) {
      if (count < 1) throw ArgumentError.value(count, 'copies[$cardId]', 'Число копий должно быть больше нуля');
    }
    await _db.transaction(() async {
      for (final MapEntry(key: cardId, value: count) in copies.entries) {
        await _db.customInsert(
          'INSERT INTO owned_cards (card_id, copies) VALUES (?, ?) '
          'ON CONFLICT(card_id) DO UPDATE SET copies = copies + excluded.copies',
          variables: [Variable<String>(cardId), Variable<int>(count)],
          updates: {_db.ownedCardEntries},
        );
      }
    });
  }

  CardCollection _toCollection(List<OwnedCardRow> rows) =>
      CardCollection({for (final row in rows) row.cardId: row.copies});
}
