import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/domain/campaign_match_facts.dart';
import 'package:gwent/src/features/campaign/domain/campaign_path.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/campaign/domain/campaign_totals.dart';
import 'package:gwent/src/features/campaign/domain/faction_readiness.dart';
import 'package:gwent/src/features/collection/domain/collection_repository.dart';
import 'package:gwent/src/features/collection/domain/owned_cards.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';
import 'package:gwent_content/gwent_content.dart';
import 'package:meta/meta.dart';

/// Результат партии узла для экрана награды и тропы.
@immutable
sealed class CampaignResult {
  const CampaignResult();
}

/// Победы нет (поражение, сдача, обрыв, ничья): ничего не выдано и не записано.
final class CampaignNoReward extends CampaignResult {
  /// Создаёт результат.
  const CampaignNoReward();
}

/// Победа записана.
final class CampaignWon extends CampaignResult {
  /// Создаёт результат победы.
  CampaignWon({
    required this.nodeId,
    required this.firstWin,
    required List<CardGrant> firstWinReward,
    required this.bonusMet,
    required List<CardGrant> bonusReward,
    required this.openedBefore,
    required this.openedAfter,
    required this.totalCards,
    required List<String> unlockedNodeIds,
    required this.chapterCleared,
    required Set<String> newFactionIds,
    Set<String> newCardIds = const {},
  }) : firstWinReward = List.unmodifiable(firstWinReward),
       bonusReward = List.unmodifiable(bonusReward),
       unlockedNodeIds = List.unmodifiable(unlockedNodeIds),
       newFactionIds = Set.unmodifiable(newFactionIds),
       newCardIds = Set.unmodifiable(newCardIds);

  /// Выигранный узел.
  final String nodeId;

  /// Это первая победа в узле: награда первой победы выдана сейчас.
  final bool firstWin;

  /// Выданная награда первой победы (с учётом предела копий); пуста при повторе.
  final List<CardGrant> firstWinReward;

  /// Условие дополнительной награды выполнено в этой партии (в том числе когда награда уже была получена раньше).
  final bool bonusMet;

  /// Выданная сейчас дополнительная награда; пуста, если условие не выполнено или награда уже получена.
  final List<CardGrant> bonusReward;

  /// Сколько копий было открыто до победы.
  final int openedBefore;

  /// Сколько копий открыто теперь.
  final int openedAfter;

  /// Сколько всего копий карт и лидеров в пакете («Открыто N из M»).
  final int totalCards;

  /// Узлы, которые победа открыла.
  final List<String> unlockedNodeIds;

  /// Глава, которую эта победа закончила (побеждён босс или пройден последний основной узел); `null` иначе.
  final CampaignChapter? chapterCleared;

  /// Фракции, колода которых собирается только теперь.
  final Set<String> newFactionIds;

  /// Выданные сейчас карты, которых у игрока раньше не было вовсе («Новая карта», а не «+1 копия»).
  final Set<String> newCardIds;

  /// Награда новой победы пуста: повтор без условия.
  bool get isEmpty => firstWinReward.isEmpty && bonusReward.isEmpty;
}

/// Сценарий: записать итог партии узла и выдать награды (ADR 0033).
///
/// Выдаётся только победа: поражение, сдача, выход и обрыв ничего не пишут. Награда первой победы выдаётся один
/// раз, награда за условие один раз (условие можно выполнить и при повторе узла). Число копий карты не может
/// превысить её `count` в пакете: лишнее отбрасывается. Запись победы и выдача карт идут одной транзакцией
/// (`CampaignRepository.recordWin`). Победа в первом узле создаёт ещё и стартовую колоду кампании и запоминает её.
final class RecordCampaignResult {
  /// Создаёт сценарий.
  RecordCampaignResult(
    this._campaign,
    this._repository,
    this._collection,
    this._decks,
    this._settings,
    this._clock,
  );

  final LoadCampaign _campaign;
  final CampaignRepository _repository;
  final CollectionRepository _collection;
  final DeckRepository _decks;
  final SettingsRepository _settings;
  final Clock _clock;

  /// Идентификатор стартовой колоды кампании: колода одна, повторная запись заменяет её, а не плодит копии.
  static const String starterDeckId = 'campaign-starter';

  /// Записывает итог партии узла [nodeId] по [facts].
  ///
  /// Записи идут по одной (очередью): «прочитать прогресс, посчитать награду, записать» не должно пересекаться
  /// у двух вызовов, иначе награда первой победы выдалась бы дважды.
  ///
  /// Бросает [ArgumentError], если узла нет в каталоге, и [StateError], если каталога кампании нет.
  Future<CampaignResult> call(String nodeId, CampaignMatchFacts facts) {
    final result = _queue.then((_) => _record(nodeId, facts));
    // Очередь не должна ломаться из-за ошибки одной записи: следующая идёт, ошибка уходит тому, кто вызывал.
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _queue = Future.value();

  Future<CampaignResult> _record(String nodeId, CampaignMatchFacts facts) async {
    final data = await _campaign() ?? (throw StateError('В пакете контента нет каталога кампании'));
    final node = data.catalog.nodesById[nodeId] ?? (throw ArgumentError.value(nodeId, 'nodeId', 'Нет такого узла'));
    if (!facts.won) return const CampaignNoReward();

    final progressBefore = await _repository.load();
    final before = await _collection.load();
    final pathBefore = CampaignPath.build(data.catalog, progressBefore);
    final progress = progressBefore[nodeId];
    final firstWin = progress == null;

    final bonus = node.bonus;
    final bonusMet = bonus != null && facts.meets(bonus.condition);
    final claimsBonus = bonusMet && !(progress?.bonusClaimed ?? false);

    final rules = data.pack.rules;
    final firstWinReward = firstWin ? _capped(rules, before, node.reward, const []) : <CardGrant>[];
    final bonusReward = claimsBonus ? _capped(rules, before, bonus.reward, firstWinReward) : <CardGrant>[];

    final grants = <String, int>{};
    for (final grant in [...firstWinReward, ...bonusReward]) {
      grants.update(grant.cardId, (copies) => copies + grant.copies, ifAbsent: () => grant.copies);
    }

    if (firstWin && node.id == data.catalog.firstNode.id) await _saveStarterDeck(data, node.reward);
    await _repository.recordWin(NodeWin(nodeId: nodeId, at: _clock.now(), grants: grants, claimsBonus: claimsBonus));

    final after = await _collection.load();
    final pathAfter = CampaignPath.build(data.catalog, await _repository.load());
    final chapterBefore = pathBefore.chapters.firstWhere(
      (chapter) => chapter.nodes.any((view) => view.node.id == nodeId),
    );
    final chapterAfter = pathAfter.chapters.firstWhere(
      (chapter) => chapter.nodes.any((view) => view.node.id == nodeId),
    );
    return CampaignWon(
      nodeId: nodeId,
      firstWin: firstWin,
      firstWinReward: firstWinReward,
      bonusMet: bonusMet,
      bonusReward: bonusReward,
      openedBefore: before.total,
      openedAfter: after.total,
      totalCards: totalCardCopies(rules),
      unlockedNodeIds: [
        for (final view in pathAfter.nodes)
          if (view.status == NodeStatus.open && pathBefore.node(view.node.id)?.status == NodeStatus.locked)
            view.node.id,
      ],
      chapterCleared: !chapterBefore.isCleared && chapterAfter.isCleared ? chapterAfter.chapter : null,
      newFactionIds: readyFactions(rules, after).difference(readyFactions(rules, before)),
      newCardIds: {
        for (final cardId in grants.keys)
          if (before.copiesOf(cardId) == 0) cardId,
      },
    );
  }

  /// Награда с учётом предела: копий карты не больше, чем `count` в пакете, считая уже открытые и выданные в этой же
  /// победе ([alreadyGranted]).
  List<CardGrant> _capped(PackRules rules, OwnedCards owned, List<CardGrant> reward, List<CardGrant> alreadyGranted) {
    final result = <CardGrant>[];
    for (final grant in reward) {
      final limit = _limit(rules, grant.cardId);
      final taken = alreadyGranted
          .where((other) => other.cardId == grant.cardId)
          .fold(0, (sum, other) => sum + other.copies);
      final room = limit - owned.copiesOf(grant.cardId) - taken;
      final copies = grant.copies < room ? grant.copies : room;
      if (copies > 0) result.add(CardGrant(cardId: grant.cardId, copies: copies));
    }
    return result;
  }

  int _limit(PackRules rules, String cardId) =>
      rules.squadCardsById[cardId]?.count ??
      rules.specialCardsById[cardId]?.count ??
      (rules.leaderCardsById.containsKey(cardId) ? 1 : 0);

  /// Стартовая колода кампании: лидер из каталога и все карты награды первого узла, кроме лидеров.
  ///
  /// Колода пишется до победы под постоянным идентификатором: если запись победы потом не удалась, повтор заменит
  /// колоду той же записью, а не создаст вторую.
  Future<void> _saveStarterDeck(CampaignData data, List<CardGrant> reward) async {
    final rules = data.pack.rules;
    final leader = rules.leaderCardsById[data.catalog.starterDeck.leaderId]!;
    final deck = Deck(
      id: starterDeckId,
      name: data.text(data.catalog.starterDeck.nameKey),
      factionId: leader.fractionId,
      leaderId: leader.id,
      cards: {
        for (final grant in reward)
          if (!rules.leaderCardsById.containsKey(grant.cardId)) grant.cardId: grant.copies,
      },
      updatedAt: _clock.now(),
    );
    await _decks.save(deck);
    final settings = await _settings.watch().first;
    await _settings.save(settings.withCampaignDeck(deck.id));
  }
}
