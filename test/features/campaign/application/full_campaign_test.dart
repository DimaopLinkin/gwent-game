import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/application/sync_campaign_rewards.dart';
import 'package:gwent/src/features/campaign/data/drift_campaign_repository.dart';
import 'package:gwent/src/features/campaign/domain/campaign_match_facts.dart';
import 'package:gwent/src/features/campaign/domain/campaign_path.dart';
import 'package:gwent/src/features/collection/data/drift_collection_repository.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';

import '../../../support/fakes.dart';
import '../../../support/test_database.dart';

/// Вся кампания на настоящих данных: 49 узлов по порядку каталога, глава за главой.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoadGameContent content;
  late CampaignData data;

  setUpAll(() async {
    content = LoadGameContent(AssetContentSource.basePack(rootBundle));
    data = (await LoadCampaign(content)())!;
  });

  /// Победа 2:0 с перевесом от 20 и без особых карт: выполняет любое условие дополнительной награды.
  final flawless = CampaignMatchFacts(
    won: true,
    rounds: const [
      RoundScore(mine: 45, theirs: 10, won: true),
      RoundScore(mine: 40, theirs: 12, won: true),
    ],
  );

  /// Победа 2:1 с тремя особыми картами и без перевеса: ни одно условие дополнительной награды не выполнено.
  final scraped = CampaignMatchFacts(
    won: true,
    rounds: const [
      RoundScore(mine: 20, theirs: 10, won: true),
      RoundScore(mine: 5, theirs: 9, won: false),
      RoundScore(mine: 9, theirs: 8, won: true),
    ],
    specialsPlayed: 3,
  );

  /// Проходит все узлы каталога по порядку с итогом [facts]; возвращает, на каком узле открылась колода фракции.
  Future<(Map<String, String>, DriftCollectionRepository, DriftCampaignRepository)> walk(
    CampaignMatchFacts facts,
    Map<String, String> clearedAt, {
    required bool bonusMet,
  }) async {
    final database = openTestDatabase();
    addTearDown(database.close);
    final progress = DriftCampaignRepository(database);
    final collection = DriftCollectionRepository(database);
    final record = RecordCampaignResult(
      LoadCampaign(content),
      progress,
      collection,
      InMemoryDeckRepository(),
      InMemorySettingsRepository(),
      FakeClock(DateTime.utc(2026, 10, 27, 12)),
    );
    final factionAt = <String, String>{};
    for (final node in data.catalog.nodes) {
      final view = CampaignPath.build(data.catalog, await progress.load()).node(node.id)!;
      expect(view.isPlayable, isTrue, reason: '${node.id} должен быть открыт к своей очереди');
      final result = await record(node.id, facts) as CampaignWon;
      expect(result.firstWin, isTrue, reason: node.id);
      if (node.bonus != null) expect(result.bonusMet, bonusMet, reason: node.id);
      if (result.chapterCleared case final chapter?) clearedAt[chapter.id] = node.id;
      for (final faction in result.newFactionIds) {
        factionAt[data.pack.rules.fractionsById[faction]!.key] = node.id;
      }
    }
    return (factionAt, collection, progress);
  }

  test('все главы играбельны, открываются по порядку, награды открывают каждую карту ровно на count', () async {
    final clearedAt = <String, String>{};
    final (_, collection, progress) = await walk(flawless, clearedAt, bonusMet: true);

    expect(clearedAt, {'c1': 'c1-09', 'c2': 'c2-12', 'c3': 'c3-14', 'c4': 'c4-10'});
    final owned = await collection.load();
    final rules = data.pack.rules;
    for (final card in rules.squadCards) {
      expect(owned.copiesOf(card.id), card.count, reason: data.text(card.nameKey));
    }
    for (final card in rules.specialCards) {
      expect(owned.copiesOf(card.id), card.count, reason: data.text(card.nameKey));
    }
    for (final leader in rules.leaderCards) {
      expect(owned.copiesOf(leader.id), 1, reason: data.text(leader.nameKey));
    }

    expect(
      await SyncCampaignRewards(LoadCampaign(content), progress, collection)(),
      0,
      reason: 'кто прошёл кампанию победами, сверка ничего не добавляет',
    );

    final end = CampaignPath.build(data.catalog, await progress.load());
    expect(end.passedCount, end.totalCount);
    expect(end.current, isNull);
    expect(end.chapters.every((chapter) => chapter.isCleared), isTrue);
  });

  test('без дополнительных наград колода каждой фракции собирается на узле из campaign-nodes.md', () async {
    final (factionAt, _, _) = await walk(scraped, {}, bonusMet: false);

    expect(factionAt, {
      'northern_realms': 'c1-00',
      'monsters': 'c2-06',
      'scoia_tael': 'c2-08',
      'nilfgaardian_empire': 'c3-04',
      'skellige': 'c4-03',
    });
  });
}
