import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/campaign/application/claim_starting_set.dart';
import 'package:gwent/src/features/campaign/application/get_campaign_deck.dart';
import 'package:gwent/src/features/campaign/application/list_campaign_decks.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/prepare_campaign_match.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/domain/campaign_match_facts.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' as history;
import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent/src/features/match_history/domain/replay_recorder.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;
import 'package:gwent_content/gwent_content.dart' show BonusCondition;
import 'package:gwent_engine/gwent_engine.dart' hide Deck;

import '../../../support/bot_match.dart';
import '../../../support/campaign_fixtures.dart';
import '../../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoadGameContent content;
  late CampaignData data;
  late InMemoryCollectionRepository collection;
  late InMemoryCampaignRepository progress;
  late InMemoryDeckRepository decks;
  late InMemorySettingsRepository settings;
  late RecordCampaignResult record;
  late GameContentDeckRulesSource rules;

  setUpAll(() async {
    content = LoadGameContent(AssetContentSource.basePack(rootBundle));
    data = (await LoadCampaign(content)())!;
  });

  setUp(() {
    collection = InMemoryCollectionRepository();
    progress = InMemoryCampaignRepository(collection);
    decks = InMemoryDeckRepository();
    settings = InMemorySettingsRepository();
    rules = GameContentDeckRulesSource(content);
    record = RecordCampaignResult(
      LoadCampaign(content),
      progress,
      collection,
      decks,
      settings,
      FakeClock(DateTime.utc(2026, 10, 27)),
    );
  });

  group('стартовый набор тому, кто прошёл «Первую партию» в обучении', () {
    ClaimStartingSet claim() => ClaimStartingSet(LoadCampaign(content), progress, settings, record);

    test('при первом входе в кампанию выдаёт набор, помечает узел 0 и создаёт колоду', () async {
      await settings.save(settings.saved.copyWith(firstMatchPassed: true));

      final won = await claim()();

      expect(won!.nodeId, 'c1-00');
      expect((await progress.load())['c1-00']!.wins, 1);
      expect((await collection.load()).copiesOf(idOf(data, 'Золтан Хивай')), 1);
      expect(await decks.watchAll().first, hasLength(1));
    });

    test('условие «без особых карт» без партии не выполнено: дополнительной награды нет', () {
      expect(const CampaignMatchFacts.withoutMatch().meets(BonusCondition.noSpecials), isFalse);
      expect(const CampaignMatchFacts.withoutMatch().meets(BonusCondition.winTwoZero), isFalse);
    });

    test('второй вход ничего не выдаёт', () async {
      await settings.save(settings.saved.copyWith(firstMatchPassed: true));
      await claim()();

      expect(await claim()(), isNull);
      expect(await decks.watchAll().first, hasLength(1));
    });

    test('два входа одновременно: набор выдан один раз, второй вызов ничего не показывает', () async {
      await settings.save(settings.saved.copyWith(firstMatchPassed: true));

      final once = claim();
      final results = await Future.wait([once(), once()]);

      expect(results.whereType<CampaignWon>(), hasLength(1));
      expect((await progress.load())['c1-00']!.wins, 1);
    });

    test('обучение не пройдено: набор не выдаётся, его выдаст партия миссии 0', () async {
      expect(await claim()(), isNull);
      expect((await collection.load()).total, 0);
    });
  });

  group('подготовка партии узла', () {
    PrepareCampaignMatch prepare() => PrepareCampaignMatch(
      LoadCampaign(content),
      progress,
      GetCampaignDeck(ListCampaignDecks(decks, rules, collection), settings),
      record,
    );

    Future<CampaignResult> passFirstNode() => record('c1-00', CampaignMatchFacts(won: true));

    test('закрытый, сценарный и невыпущенный узлы не играются', () async {
      await passFirstNode();

      for (final nodeId in ['c1-02', 'c1-00', 'c2-00', 'c9-99']) {
        final result = await prepare()(nodeId, onResult: (_) {});
        expect(result, isA<CampaignNodeUnavailable>(), reason: nodeId);
      }
    });

    test('нет годной колоды: предлагается собрать её', () async {
      await progress.recordWin(NodeWin(nodeId: 'c1-00', at: DateTime.utc(2026, 10, 27)));

      expect(await prepare()('c1-01', onResult: (_) {}), isA<CampaignDeckMissing>());
    });

    test('запрос: колода игрока, колода и уровень противника из узла, колода не в хранилище', () async {
      await passFirstNode();
      final starter = (await decks.watchAll().first).single;

      final prepared = await prepare()('c1-01', onResult: (_) {}) as CampaignMatchPrepared;
      final request = prepared.request;

      expect(request.mode, LocalMatchMode.vsBot);
      expect(request.deckOne, starter.id);
      expect(request.deckTwo, PrepareCampaignMatch.opponentDeckId('c1-01'));
      expect(request.difficulty, BotDifficulty.easy);
      final opponent = request.opponentDeck!;
      expect(opponent.leaderId, prepared.node.opponent.leaderId);
      expect(opponent.name, 'Трактирщик из Белого сада');
      expect(await decks.findById(opponent.id), isNull);
    });

    test('колоды противников всех узлов проходят правила сборки своей фракции', () async {
      await passFirstNode();
      final deckRules = await rules.load();
      for (final node in data.catalog.nodes.where((node) => !node.isScripted)) {
        final prepared = _preparedOpponent(data, node.id);
        expect(deckRules.check(prepared), isEmpty, reason: '${node.id}: ${deckRules.check(prepared)}');
      }
    });

    test('дымовой тест: с колодой каждого узла (все четыре главы) партия против бота доходит до итога', () async {
      await passFirstNode();
      final gameContent = await readyContent(content);
      final player = (await decks.watchAll().first).single;
      for (final node in data.catalog.nodes.where((node) => !node.isScripted)) {
        final match = playBotMatch(gameContent, player, _preparedOpponent(data, node.id), seed: 7);
        expect(match.finalView.outcome, isNotNull, reason: node.id);
      }
    });

    test('партия без журнала: ошибка уходит в onError, а не тихий отказ в награде', () async {
      await passFirstNode();
      final errors = <Object>[];
      final prepared =
          await prepare()('c1-01', onResult: (_) {}, onError: (error, _) => errors.add(error)) as CampaignMatchPrepared;
      final gameContent = await readyContent(content);
      final session = MatchSession(
        mode: history.MatchMode.ai,
        table: _NoTable(),
        content: gameContent,
        factionIds: const {Seat.one: 'a', Seat.two: 'b'},
      );
      final finalView = playBotMatch(
        gameContent,
        (await decks.watchAll().first).single,
        prepared.request.opponentDeck!,
      ).finalView;

      await prepared.request.onFinished!(session, finalView);

      expect(errors.single, isA<StateError>());
      expect((await progress.load()).containsKey('c1-01'), isFalse);
    });

    test('по концу партии итог доходит до onResult: победа выдаёт награду, поражение нет', () async {
      await passFirstNode();
      final results = <CampaignResult>[];
      final prepared = await prepare()('c1-01', onResult: results.add) as CampaignMatchPrepared;
      final gameContent = await readyContent(content);
      final player = (await decks.watchAll().first).single;

      // Две партии бот против бота: играем сидами, пока одна не окажется победой первого места, другая поражением.
      BotMatch? victory;
      BotMatch? defeat;
      for (var seed = 1; seed < 40 && (victory == null || defeat == null); seed++) {
        final match = playBotMatch(gameContent, player, prepared.request.opponentDeck!, seed: seed);
        if (match.finalView.outcome!.winner == Seat.one) {
          victory ??= match;
        } else {
          defeat ??= match;
        }
      }
      expect(victory, isNotNull, reason: 'нужна партия, выигранная первым местом');

      Future<void> finish(BotMatch match) async {
        final session = MatchSession(
          mode: history.MatchMode.ai,
          table: _NoTable(),
          content: gameContent,
          factionIds: const {Seat.one: 'a', Seat.two: 'b'},
          recorder: _Recorder(JournalReplayLog(match.record, perspective: Seat.one)),
          onFinished: prepared.request.onFinished,
        );
        await prepared.request.onFinished!(session, match.finalView);
      }

      if (defeat != null) {
        await finish(defeat);
        expect(results.single, isA<CampaignNoReward>());
        expect((await progress.load()).containsKey('c1-01'), isFalse);
      }
      results.clear();
      await finish(victory!);
      expect(results.single, isA<CampaignWon>());
      expect((results.single as CampaignWon).firstWinReward.single.cardId, idOf(data, 'Корова'));
      expect((await progress.load())['c1-01']!.wins, 1);
    });
  });
}

Deck _preparedOpponent(CampaignData data, String nodeId) {
  final opponent = data.catalog.nodesById[nodeId]!.opponent;
  return Deck(
    id: nodeId,
    name: nodeId,
    factionId: opponent.fractionId!,
    leaderId: opponent.leaderId!,
    cards: {for (final grant in opponent.deck) grant.cardId: grant.copies},
    updatedAt: DateTime.utc(2026),
  );
}

final class _Recorder implements ReplayRecorder {
  const _Recorder(this.log);

  @override
  final ReplayLog? log;
}

final class _NoTable implements MatchTable {
  @override
  Set<Seat> get localSeats => {Seat.one};

  @override
  Stream<TableUpdate> get updates => const Stream.empty();

  @override
  void submit(Seat seat, Intent intent) {}

  @override
  Future<void> close() async {}
}
