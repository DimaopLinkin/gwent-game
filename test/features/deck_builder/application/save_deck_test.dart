import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/application/delete_deck.dart';
import 'package:gwent/src/features/deck_builder/application/save_deck.dart';

import '../../../support/fakes.dart';

void main() {
  late InMemoryDeckRepository repository;
  late FakeClock clock;
  late SaveDeck saveDeck;

  setUp(() {
    repository = InMemoryDeckRepository();
    clock = FakeClock(DateTime.utc(2026, 10, 11, 9));
    saveDeck = SaveDeck(repository, clock, SequentialIdGenerator());
  });

  Future<String> saveNew() async =>
      (await saveDeck(name: 'Скеллиге', factionId: 'f', leaderId: 'l', cards: const {'a': 2})).id;

  test('новая колода получает идентификатор и время сохранения', () async {
    final id = await saveNew();

    final saved = await repository.findById(id);
    expect(saved?.id, 'id-1');
    expect(saved?.updatedAt, clock.current);
    expect(saved?.cards, {'a': 2});
  });

  test('сохранение с идентификатором заменяет колоду и обновляет время', () async {
    final id = await saveNew();
    clock.current = DateTime.utc(2026, 10, 12);

    await saveDeck(id: id, name: 'Другая', factionId: 'f', leaderId: 'l', cards: const {'b': 1});

    final saved = await repository.findById(id);
    expect(saved?.name, 'Другая');
    expect(saved?.cards, {'b': 1});
    expect(saved?.updatedAt, DateTime.utc(2026, 10, 12));
  });

  test('удаление убирает колоду', () async {
    final id = await saveNew();

    await DeleteDeck(repository)(id);

    expect(await repository.findById(id), isNull);
  });
}
