import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/collection/data/drift_collection_repository.dart';
import 'package:gwent/src/features/collection/domain/owned_cards.dart';

import '../../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftCollectionRepository repository;

  setUp(() {
    db = openTestDatabase();
    repository = DriftCollectionRepository(db);
  });

  tearDown(() => db.close());

  test('у игрока, не начинавшего кампанию, коллекция пуста', () async {
    expect(await repository.load(), CardCollection.empty);
  });

  test('открытые карты читаются с числом копий', () async {
    await repository.grant(const {'a': 2, 'leader': 1});

    final collection = await repository.load();

    expect(collection.copiesOf('a'), 2);
    expect(collection.copiesOf('leader'), 1);
    expect(collection.copiesOf('нет'), 0);
  });

  test('повторная выдача прибавляет копии, а не заменяет их', () async {
    await repository.grant(const {'a': 1, 'b': 3});
    await repository.grant(const {'a': 2, 'c': 1});

    expect((await repository.load()).copies, {'a': 3, 'b': 3, 'c': 1});
  });

  test('число копий меньше единицы отклоняется, и не открывается ничего', () async {
    await expectLater(repository.grant(const {'a': 1, 'b': 0}), throwsArgumentError);

    expect(await repository.load(), CardCollection.empty);
  });

  test('поток выдаёт новый снимок после каждой выдачи', () async {
    final snapshots = <Map<String, int>>[];
    final subscription = repository.watch().listen((collection) => snapshots.add(collection.copies));
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await repository.grant(const {'a': 1});
    await pumpEventQueue();
    await repository.grant(const {'a': 1});
    await pumpEventQueue();

    expect(snapshots, [
      const <String, int>{},
      {'a': 1},
      {'a': 2},
    ]);
  });
}
