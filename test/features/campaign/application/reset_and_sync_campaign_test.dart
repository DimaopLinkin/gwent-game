import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/application/reset_campaign.dart';
import 'package:gwent/src/features/campaign/application/sync_campaign_rewards.dart';
import 'package:gwent/src/features/campaign/data/drift_campaign_repository.dart';
import 'package:gwent/src/features/campaign/domain/campaign_match_facts.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/collection/data/drift_collection_repository.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';

import '../../../support/campaign_fixtures.dart';
import '../../../support/fakes.dart';
import '../../../support/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoadGameContent content;
  late CampaignData data;
  late AppDatabase database;
  late DriftCampaignRepository progress;
  late DriftCollectionRepository collection;
  late InMemoryDeckRepository decks;
  late InMemorySettingsRepository settings;
  late RecordCampaignResult record;

  setUpAll(() async {
    content = LoadGameContent(AssetContentSource.basePack(rootBundle));
    data = (await LoadCampaign(content)())!;
  });

  setUp(() {
    database = openTestDatabase();
    progress = DriftCampaignRepository(database);
    collection = DriftCollectionRepository(database);
    decks = InMemoryDeckRepository();
    settings = InMemorySettingsRepository();
    record = RecordCampaignResult(
      LoadCampaign(content),
      progress,
      collection,
      decks,
      settings,
      FakeClock(DateTime.utc(2026, 10, 27, 12)),
    );
  });

  tearDown(() => database.close());

  String id(String name) => idOf(data, name);

  /// Помечает узлы пройденными без выдачи карт: так выглядит прогресс игрока, который прошёл их до смены раздачи.
  Future<void> passWithoutGrants(Iterable<String> nodeIds, {Iterable<String> bonusClaimed = const []}) async {
    for (final nodeId in nodeIds) {
      await progress.recordWin(
        NodeWin(nodeId: nodeId, at: DateTime.utc(2026, 10), claimsBonus: bonusClaimed.contains(nodeId)),
      );
    }
  }

  group('ResetCampaign', () {
    late ResetCampaign reset;

    setUp(() => reset = ResetCampaign(progress, settings));

    test('стирает прогресс и открытые карты, забывает колоду кампании, оставляет колоды игрока', () async {
      await record('c1-00', CampaignMatchFacts(won: true));
      await record('c1-01', CampaignMatchFacts(won: true));
      expect(await progress.load(), hasLength(2));
      expect((await collection.load()).total, greaterThan(0));
      expect(settings.saved.campaignDeckId, RecordCampaignResult.starterDeckId);

      await reset();

      expect(await progress.load(), isEmpty);
      expect((await collection.load()).total, 0);
      expect(settings.saved.campaignDeckId, isNull);
      expect(
        (await decks.watchAll().first).map((deck) => deck.id),
        [RecordCampaignResult.starterDeckId],
        reason: 'колоды лежат отдельно от кампании и остаются',
      );
    });

    test('другие настройки не трогает', () async {
      await settings.save(settings.saved.copyWith(confirmPass: false, firstMatchPassed: true));
      await record('c1-00', CampaignMatchFacts(won: true));

      await reset();

      expect(settings.saved.confirmPass, isFalse);
      expect(settings.saved.firstMatchPassed, isTrue);
    });

    test('после сброса первый узел снова выдаёт стартовый набор и стартовую колоду', () async {
      await record('c1-00', CampaignMatchFacts(won: true));
      await reset();

      final again = await record('c1-00', CampaignMatchFacts(won: true)) as CampaignWon;

      expect(again.firstWin, isTrue);
      expect(again.openedBefore, 0);
      expect((await collection.load()).copiesOf(id('Золтан Хивай')), 1);
      expect(settings.saved.campaignDeckId, RecordCampaignResult.starterDeckId);
      expect(await decks.watchAll().first, hasLength(1));
    });

    test('на пустой кампании ничего не ломает', () async {
      await reset();

      expect(await progress.load(), isEmpty);
    });
  });

  group('SyncCampaignRewards', () {
    late SyncCampaignRewards sync;

    setUp(() => sync = SyncCampaignRewards(LoadCampaign(content), progress, collection));

    test('новая кампания: выдавать нечего', () async {
      expect(await sync(), 0);
      expect((await collection.load()).total, 0);
    });

    test('добирает награды пройденных узлов, которые не были выданы', () async {
      // Игрок прошёл три узла со стопкой Чучел до смены раздачи: копии за c1-05 и c1-08 ему не выдавались.
      await passWithoutGrants(['c1-00', 'c1-01', 'c1-02', 'c1-03', 'c1-05', 'c1-06', 'c1-08']);

      await sync();

      final owned = await collection.load();
      expect(owned.copiesOf(id('Чучело')), 2, reason: 'c1-05 и c1-08; копия c1-02 только за условие');
      expect(owned.copiesOf(id('Корова')), 1);
      expect(owned.copiesOf(id('Золтан Хивай')), 1, reason: 'награда первого узла тоже сверяется');
    });

    test('награду за условие добирает только там, где она получена', () async {
      await passWithoutGrants(
        ['c1-00', 'c1-01', 'c1-02', 'c1-03', 'c1-05', 'c1-06', 'c1-08'],
        bonusClaimed: ['c1-02', 'c1-08'],
      );

      await sync();

      final owned = await collection.load();
      expect(owned.copiesOf(id('Чучело')), 3, reason: 'c1-02 (условие), c1-05 и c1-08');
      expect(owned.copiesOf(id('Катапульта')), 2, reason: 'условие c1-08 получено');
      expect(owned.copiesOf(id('Осадная башня')), 0, reason: 'условие c1-06 не получено');
    });

    test('одновременные сверки (старая и новая тропа) выдают недостающее один раз', () async {
      await passWithoutGrants(['c1-00', 'c1-01', 'c1-02', 'c1-03', 'c1-05', 'c1-06', 'c1-08']);

      final added = await Future.wait([sync(), sync(), sync()]);

      expect((await collection.load()).copiesOf(id('Чучело')), 2);
      expect(added.where((copies) => copies > 0), hasLength(1));
    });

    test('повторная сверка ничего не выдаёт', () async {
      await passWithoutGrants(['c1-00', 'c1-01', 'c1-02', 'c1-03', 'c1-05']);
      await sync();
      final first = await collection.load();

      expect(await sync(), 0);

      expect((await collection.load()).copies, first.copies);
    });

    test('ничего не отнимает: если копий больше, чем даёт пройденное, остаются все', () async {
      await passWithoutGrants(['c1-00', 'c1-01', 'c1-02'], bonusClaimed: ['c1-02']);
      await collection.grant({id('Чучело'): 3});

      await sync();

      expect((await collection.load()).copiesOf(id('Чучело')), 3);
    });

    test('добирает только недостающее до суммы наград', () async {
      await passWithoutGrants(['c1-00', 'c1-01', 'c1-02', 'c1-03', 'c1-05', 'c1-06', 'c1-08'], bonusClaimed: ['c1-02']);
      await collection.grant({id('Чучело'): 2});

      await sync();

      expect((await collection.load()).copiesOf(id('Чучело')), 3);
    });

    test('учитывает уже выданное победами: игрок, прошедший кампанию обычным путём, ничего не получает', () async {
      await record('c1-00', CampaignMatchFacts(won: true));
      await record('c1-01', CampaignMatchFacts(won: true));
      final before = await collection.load();

      expect(await sync(), 0);

      expect((await collection.load()).copies, before.copies);
    });
  });
}
