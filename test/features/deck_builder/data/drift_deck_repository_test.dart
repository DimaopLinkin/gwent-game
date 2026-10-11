import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/deck_builder/data/drift_deck_repository.dart';

import '../../../support/factories.dart';
import '../../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftDeckRepository repository;

  setUp(() {
    db = openTestDatabase();
    repository = DriftDeckRepository(db);
  });

  tearDown(() => db.close());

  test('сохранённая колода читается без изменений', () async {
    final deck = testDeck(updatedAt: DateTime.utc(2026, 10, 11, 12, 30, 15, 250));

    await repository.save(deck);

    expect(await repository.findById(deck.id), deck);
    expect(await repository.findById('нет такой'), isNull);
  });

  test('колода без карт сохраняется', () async {
    final deck = testDeck(cards: const {});

    await repository.save(deck);

    expect(await repository.findById(deck.id), deck);
  });

  test('повторное сохранение заменяет состав колоды', () async {
    await repository.save(testDeck(cards: const {'a': 1, 'b': 2}));
    final updated = testDeck(name: 'Новая', cards: const {'c': 3});

    await repository.save(updated);

    expect(await repository.findById(updated.id), updated);
  });

  test('список отсортирован по времени изменения и обновляется после сохранения', () async {
    final older = testDeck(id: 'old', updatedAt: DateTime.utc(2026, 10, 3));
    final newer = testDeck(id: 'new', updatedAt: DateTime.utc(2026, 10, 4));

    final lists = repository.watchAll().map((decks) => [for (final deck in decks) deck.id]);
    final expectation = expectLater(
      lists,
      emitsInOrder([
        isEmpty,
        ['old'],
        ['new', 'old'],
      ]),
    );
    await pumpEventQueue();
    await repository.save(older);
    await pumpEventQueue();
    await repository.save(newer);
    await expectation;
  });

  test('удаление колоды удаляет её карты', () async {
    final deck = testDeck();
    await repository.save(deck);

    await repository.delete(deck.id);

    expect(await repository.findById(deck.id), isNull);
    expect(await db.select(db.deckCards).get(), isEmpty);
  });
}
