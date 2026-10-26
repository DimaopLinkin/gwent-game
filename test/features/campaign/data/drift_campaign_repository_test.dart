import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/campaign/data/drift_campaign_repository.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/collection/data/drift_collection_repository.dart';

import '../../../support/test_database.dart';

void main() {
  late AppDatabase database;
  late DriftCampaignRepository repository;
  late DriftCollectionRepository collection;

  setUp(() {
    database = openTestDatabase();
    repository = DriftCampaignRepository(database);
    collection = DriftCollectionRepository(database);
  });

  tearDown(() => database.close());

  final first = DateTime.utc(2026, 10, 27, 10);
  final second = DateTime.utc(2026, 10, 27, 11);

  test('без побед прогресс пуст', () async {
    expect(await repository.load(), isEmpty);
  });

  test('первая победа пишет узел и награду вместе', () async {
    await repository.recordWin(NodeWin(nodeId: 'c1-01', at: first, grants: const {'card-a': 2, 'card-b': 1}));

    expect(await repository.load(), {'c1-01': NodeProgress(nodeId: 'c1-01', wins: 1, firstWinAt: first)});
    expect((await collection.load()).copies, {'card-a': 2, 'card-b': 1});
  });

  test(
    'повторная победа считает победы, момент первой остаётся; карты прибавляются только если они в награде',
    () async {
      await repository.recordWin(NodeWin(nodeId: 'c1-01', at: first, grants: const {'card-a': 1}));
      await repository.recordWin(NodeWin(nodeId: 'c1-01', at: second));

      final progress = (await repository.load())['c1-01']!;
      expect(progress.wins, 2);
      expect(progress.firstWinAt, first);
      expect((await collection.load()).copies, {'card-a': 1});
    },
  );

  test('награда за условие помечается один раз и не перезаписывается', () async {
    await repository.recordWin(NodeWin(nodeId: 'c1-01', at: first));
    expect((await repository.load())['c1-01']!.bonusClaimed, isFalse);

    await repository.recordWin(NodeWin(nodeId: 'c1-01', at: second, grants: const {'card-b': 1}, claimsBonus: true));
    await repository.recordWin(NodeWin(nodeId: 'c1-01', at: DateTime.utc(2026, 10, 28), claimsBonus: true));

    final progress = (await repository.load())['c1-01']!;
    expect(progress.bonusClaimedAt, second);
    expect(progress.wins, 3);
  });

  test(
    'сбой выдачи награды откатывает и пометку об узле: награда без пометки и пометка без награды невозможны',
    () async {
      await expectLater(
        repository.recordWin(NodeWin(nodeId: 'c1-01', at: first, grants: const {'card-a': 1, 'card-b': 0})),
        throwsArgumentError,
      );

      expect(await repository.load(), isEmpty);
      expect((await collection.load()).copies, isEmpty);
    },
  );

  test('сбой во второй победе не меняет первую', () async {
    await repository.recordWin(NodeWin(nodeId: 'c1-01', at: first, grants: const {'card-a': 1}));

    await expectLater(
      repository.recordWin(NodeWin(nodeId: 'c1-01', at: second, grants: const {'card-b': -1}, claimsBonus: true)),
      throwsArgumentError,
    );

    final progress = (await repository.load())['c1-01']!;
    expect(progress.wins, 1);
    expect(progress.bonusClaimed, isFalse);
    expect((await collection.load()).copies, {'card-a': 1});
  });

  test('поток выдаёт новый снимок после победы', () async {
    final snapshots = repository.watch();
    final expectation = expectLater(
      snapshots,
      emitsInOrder([
        isEmpty,
        {'c1-01': NodeProgress(nodeId: 'c1-01', wins: 1, firstWinAt: first)},
      ]),
    );
    await Future<void>.delayed(Duration.zero);
    await repository.recordWin(NodeWin(nodeId: 'c1-01', at: first));
    await expectation;
  });
}
