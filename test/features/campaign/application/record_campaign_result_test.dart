import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/data/drift_campaign_repository.dart';
import 'package:gwent/src/features/campaign/domain/campaign_match_facts.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/collection/data/drift_collection_repository.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';

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
      SequentialIdGenerator(),
    );
  });

  tearDown(() => database.close());

  String id(String name) => idOf(data, name);

  /// Победа с условиями, которые заданы в [facts] (по умолчанию ни одно не выполнено).
  CampaignMatchFacts win({List<RoundScore>? rounds, int specials = 3}) => CampaignMatchFacts(
    won: true,
    rounds:
        rounds ??
        [
          const RoundScore(mine: 20, theirs: 10, won: true),
          const RoundScore(mine: 5, theirs: 9, won: false),
          const RoundScore(mine: 9, theirs: 8, won: true),
        ],
    specialsPlayed: specials,
  );

  final flawless = [
    const RoundScore(mine: 20, theirs: 10, won: true),
    const RoundScore(mine: 15, theirs: 12, won: true),
  ];

  Future<CampaignWon> won(String nodeId, CampaignMatchFacts facts) async => await record(nodeId, facts) as CampaignWon;

  Future<void> passAll(Iterable<String> nodeIds) async {
    for (final nodeId in nodeIds) {
      await progress.recordWin(NodeWin(nodeId: nodeId, at: DateTime.utc(2026, 10)));
    }
  }

  group('первая победа', () {
    test('в первом узле выдаёт стартовый набор, лидеров и Золтана, создаёт стартовую колоду кампании', () async {
      final result = await won('c1-00', CampaignMatchFacts(won: true));

      expect(result.firstWin, isTrue);
      final owned = await collection.load();
      expect(owned.copiesOf(id('Гребаная пехтура')), 3);
      expect(owned.copiesOf(id('Золтан Хивай')), 1);
      expect(owned.copiesOf(id('Фольтест: Король Темерии')), 1);
      expect(owned.copiesOf(id('Эредин Бреакк Глас: Командир Дикой Охоты')), 1);
      expect(owned.total, result.openedAfter);
      expect(result.openedBefore, 0);
      expect((await progress.load())['c1-00']!.wins, 1);

      final deck = (await decks.watchAll().first).single;
      expect(deck.name, 'Стартовая колода');
      expect(deck.leaderId, id('Фольтест: Король Темерии'));
      expect(deck.cards[id('Золтан Хивай')], 1);
      expect(deck.cards.containsKey(deck.leaderId), isFalse);
      expect(settings.saved.campaignDeckId, deck.id);
      final rules = await GameContentDeckRulesSource(content).load();
      expect(rules.check(deck, owned: owned), isEmpty, reason: 'стартовая колода годна для кампании');
    });

    test('открывает фракцию Королевств Севера и следующий узел', () async {
      final result = await won('c1-00', CampaignMatchFacts(won: true));

      expect(result.newFactionIds.map((faction) => data.pack.rules.fractionsById[faction]!.key), {'northern_realms'});
      expect(result.unlockedNodeIds, ['c1-01']);
      expect(result.chapterCleared, isNull);
      expect(result.totalCards, 253);
    });

    test('в обычном узле выдаёт награду один раз, повтор ничего не выдаёт, но победы растут', () async {
      await passAll(['c1-00']);

      final first = await won('c1-01', win());
      expect(first.firstWin, isTrue);
      expect(first.firstWinReward.map((grant) => grant.cardId), [id('Корова')]);
      expect(first.bonusReward, isEmpty);

      final again = await won('c1-01', win());
      expect(again.firstWin, isFalse);
      expect(again.isEmpty, isTrue);
      expect((await collection.load()).copiesOf(id('Корова')), 1);
      expect((await progress.load())['c1-01']!.wins, 2);
    });

    test('победа в узле, где награда уже открыта другим путём, не превышает count карты', () async {
      await passAll(['c1-00']);
      await collection.grant({id('Корова'): 1});

      final result = await won('c1-01', win());

      expect(result.firstWinReward, isEmpty, reason: 'у Коровы одна копия, и она уже открыта');
      expect((await collection.load()).copiesOf(id('Корова')), 1);
      expect((await progress.load())['c1-01']!.wins, 1, reason: 'узел всё равно пройден');
    });
  });

  group('условие дополнительной награды', () {
    test('выполненное в первой победе выдаётся вместе с наградой и один раз', () async {
      await passAll(['c1-00']);

      final first = await won('c1-01', win(rounds: flawless));
      expect(first.bonusMet, isTrue);
      expect(first.bonusReward.map((grant) => grant.cardId), [id('Мороз')]);

      final again = await won('c1-01', win(rounds: flawless));
      expect(again.bonusMet, isTrue, reason: 'условие выполнено, но награда уже получена');
      expect(again.bonusReward, isEmpty);
      expect((await collection.load()).copiesOf(id('Мороз')), 1);
      expect((await progress.load())['c1-01']!.bonusClaimed, isTrue);
    });

    test('условие можно выполнить при повторе узла: награда придёт тогда, а не в первой победе', () async {
      await passAll(['c1-00']);
      final first = await won('c1-01', win());
      expect(first.bonusMet, isFalse);
      expect((await progress.load())['c1-01']!.bonusClaimed, isFalse);

      final repeat = await won('c1-01', win(rounds: flawless));
      expect(repeat.firstWin, isFalse);
      expect(repeat.bonusReward.map((grant) => grant.cardId), [id('Мороз')]);
      expect((await collection.load()).copiesOf(id('Мороз')), 1);
    });

    test('«без особых карт»: награда Чучело ×3 только если ни одной особой карты не сыграно', () async {
      await passAll(['c1-00', 'c1-01']);

      final withSpecials = await won('c1-02', win(specials: 2));
      expect(withSpecials.bonusReward, isEmpty);

      final clean = await won('c1-02', win(specials: 0));
      expect(clean.bonusReward.single.copies, 3);
      expect((await collection.load()).copiesOf(id('Чучело')), 3);
    });
  });

  group('поражение и сбои', () {
    test('поражение ничего не записывает и не выдаёт', () async {
      await passAll(['c1-00']);

      final result = await record('c1-01', CampaignMatchFacts(won: false));

      expect(result, isA<CampaignNoReward>());
      expect((await progress.load()).containsKey('c1-01'), isFalse);
      expect((await collection.load()).total, 0);
    });

    test('неизвестный узел: ArgumentError', () async {
      await expectLater(record('c9-99', CampaignMatchFacts(won: true)), throwsArgumentError);
    });

    test('сбой записи не оставляет награды без пометки об узле', () async {
      final failing = RecordCampaignResult(
        LoadCampaign(content),
        _FailingRepository(progress),
        collection,
        decks,
        settings,
        FakeClock(DateTime.utc(2026, 10, 27)),
        SequentialIdGenerator(),
      );
      await passAll(['c1-00']);

      await expectLater(failing('c1-01', win()), throwsStateError);

      expect((await progress.load()).containsKey('c1-01'), isFalse);
      expect((await collection.load()).copiesOf(id('Корова')), 0);
    });
  });

  group('глава и открытие узлов', () {
    test('победа над боссом заканчивает главу', () async {
      await passAll(['c1-00', 'c1-01', 'c1-02', 'c1-03', 'c1-05', 'c1-06', 'c1-08']);

      final result = await won('c1-09', win());

      expect(result.chapterCleared!.id, 'c1');
      expect(result.unlockedNodeIds, isEmpty, reason: 'глава 2 ещё не выпущена');
    });

    test('победа в c1-03 открывает основной узел и заказ', () async {
      await passAll(['c1-00', 'c1-01', 'c1-02']);

      final result = await won('c1-03', win());

      expect(result.unlockedNodeIds, unorderedEquals(['c1-04', 'c1-05']));
    });
  });
}

/// Репозиторий, у которого запись победы падает: награда не должна остаться без пометки об узле.
final class _FailingRepository implements CampaignRepository {
  const _FailingRepository(this._inner);

  final CampaignRepository _inner;

  @override
  Future<Map<String, NodeProgress>> load() => _inner.load();

  @override
  Stream<Map<String, NodeProgress>> watch() => _inner.watch();

  @override
  Future<void> recordWin(NodeWin win) => Future.error(StateError('сбой записи'));
}
