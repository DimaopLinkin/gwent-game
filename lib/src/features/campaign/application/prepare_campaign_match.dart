import 'package:gwent/src/features/campaign/application/get_campaign_deck.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/domain/campaign_match_facts.dart';
import 'package:gwent/src/features/campaign/domain/campaign_path.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;
import 'package:gwent_content/gwent_content.dart' show CampaignDifficulty, CampaignNode;
import 'package:gwent_engine/gwent_engine.dart' show GwentEngine, PlayerView;
import 'package:meta/meta.dart';

/// Итог подготовки партии узла.
@immutable
sealed class PrepareCampaignMatchResult {
  const PrepareCampaignMatchResult();
}

/// Партия готова: запрос идёт в обычную партию против бота (ADR 0006), а по её концу итог попадёт в `onResult`.
final class CampaignMatchPrepared extends PrepareCampaignMatchResult {
  /// Создаёт итог.
  const CampaignMatchPrepared(this.node, this.request);

  /// Узел.
  final CampaignNode node;

  /// Запрос на местную партию с колодой игрока и фиксированной колодой противника.
  final LocalMatchRequest request;
}

/// Годной колоды нет: игроку предлагают собрать её в конструкторе кампании.
final class CampaignDeckMissing extends PrepareCampaignMatchResult {
  /// Создаёт итог.
  const CampaignDeckMissing();
}

/// В узле нельзя играть: он закрыт, его глава ещё не выпущена, он сценарный или его нет в каталоге.
final class CampaignNodeUnavailable extends PrepareCampaignMatchResult {
  /// Создаёт итог.
  const CampaignNodeUnavailable(this.nodeId);

  /// Идентификатор узла.
  final String nodeId;
}

/// Сценарий: подготовить партию узла кампании (ADR 0033).
///
/// Колоду игрока берёт запомненная колода кампании ([GetCampaignDeck]), колоду противника, уровень и лидера задаёт
/// узел. Дальше идёт обычная партия: экран партии о кампании ничего не знает, он только вызывает хук конца
/// партии из запроса. Хук считает итог по журналу и записывает его ([RecordCampaignResult]); повтор партии
/// («Реванш») повторяет запрос и хук.
final class PrepareCampaignMatch {
  /// Создаёт сценарий.
  const PrepareCampaignMatch(this._campaign, this._repository, this._deck, this._record);

  final LoadCampaign _campaign;
  final CampaignRepository _repository;
  final GetCampaignDeck _deck;
  final RecordCampaignResult _record;

  /// Идентификатор колоды противника в запросе: в хранилище её нет.
  static String opponentDeckId(String nodeId) => 'campaign-opponent-$nodeId';

  /// Готовит партию узла [nodeId]; итог партии придёт в [onResult] по её концу.
  Future<PrepareCampaignMatchResult> call(
    String nodeId, {
    required void Function(CampaignResult result) onResult,
  }) async {
    final data = await _campaign();
    final node = data?.catalog.nodesById[nodeId];
    if (data == null || node == null || node.isScripted) return CampaignNodeUnavailable(nodeId);
    final view = CampaignPath.build(data.catalog, await _repository.load()).node(nodeId);
    if (view == null || !view.isPlayable) return CampaignNodeUnavailable(nodeId);
    final player = await _deck();
    if (player == null) return const CampaignDeckMissing();

    final opponent = node.opponent;
    final opponentDeck = Deck(
      id: opponentDeckId(nodeId),
      name: data.text(opponent.nameKey),
      factionId: opponent.fractionId!,
      leaderId: opponent.leaderId!,
      cards: {for (final grant in opponent.deck) grant.cardId: grant.copies},
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
    return CampaignMatchPrepared(
      node,
      LocalMatchRequest(
        mode: LocalMatchMode.vsBot,
        deckOne: player.id,
        deckTwo: opponentDeck.id,
        difficulty: _botDifficulty(node.difficulty),
        opponentDeck: opponentDeck,
        onFinished: (session, finalView) async => onResult(await _record(nodeId, _facts(session, finalView))),
      ),
    );
  }

  /// Итог партии по журналу сессии. Партия без журнала считается проигранной: награду без доказательства не выдаём.
  CampaignMatchFacts _facts(MatchSession session, PlayerView finalView) {
    final log = session.recorder?.log;
    if (log is! JournalReplayLog) return CampaignMatchFacts(won: false);
    final content = session.content;
    return CampaignMatchFacts.fromMatch(
      record: log.journal,
      engine: GwentEngine(content.catalog, rules: content.rules),
      catalog: content.catalog,
      finalView: finalView,
      me: session.perspective,
    );
  }

  static BotDifficulty _botDifficulty(CampaignDifficulty difficulty) => switch (difficulty) {
    CampaignDifficulty.easy => BotDifficulty.easy,
    CampaignDifficulty.normal => BotDifficulty.normal,
    CampaignDifficulty.hard => BotDifficulty.hard,
    CampaignDifficulty.deathMatch => BotDifficulty.deathMatch,
  };
}
