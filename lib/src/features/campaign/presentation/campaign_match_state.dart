import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/match/application/start_match.dart' show LocalMatchRequest;
import 'package:gwent_content/gwent_content.dart' show CampaignNode;
import 'package:meta/meta.dart';

/// Состояние экрана партии узла кампании.
@immutable
sealed class CampaignMatchState {
  const CampaignMatchState();
}

/// Партия готовится.
final class CampaignMatchLoading extends CampaignMatchState {
  /// Создаёт состояние.
  const CampaignMatchLoading();
}

/// Годной колоды нет: игрока ведут в конструктор кампании.
final class CampaignMatchNeedsDeck extends CampaignMatchState {
  /// Создаёт состояние.
  const CampaignMatchNeedsDeck();
}

/// В узле нельзя играть или партию начать не удалось.
final class CampaignMatchUnavailable extends CampaignMatchState {
  /// Создаёт состояние.
  const CampaignMatchUnavailable();
}

/// Партия узла идёт. [result] приходит после её конца и пустеет, когда начинается следующая («Реванш»).
final class CampaignMatchPlaying extends CampaignMatchState {
  /// Создаёт состояние.
  const CampaignMatchPlaying({
    required this.data,
    required this.node,
    required this.request,
    this.result,
    this.resultFailed = false,
  });

  /// Каталог и пакет с текстами.
  final CampaignData data;

  /// Узел.
  final CampaignNode node;

  /// Запрос на партию против бота с хуком конца партии.
  final LocalMatchRequest request;

  /// Итог партии для награды; `null`, пока его нет.
  final CampaignResult? result;

  /// Итог не удалось посчитать или записать: награды нет, партию можно сыграть заново.
  final bool resultFailed;

  /// Копия с новым итогом.
  CampaignMatchPlaying withResult(CampaignResult? result, {bool failed = false}) =>
      CampaignMatchPlaying(data: data, node: node, request: request, result: result, resultFailed: failed);
}
