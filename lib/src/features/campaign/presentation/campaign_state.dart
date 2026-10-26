import 'package:gwent/src/features/campaign/application/load_campaign_overview.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:meta/meta.dart';

/// Состояние тропы кампании.
@immutable
sealed class CampaignState {
  const CampaignState();
}

/// Тропа загружается.
final class CampaignLoading extends CampaignState {
  /// Создаёт состояние.
  const CampaignLoading();
}

/// В пакете карт нет каталога кампании или он не прочитался: тропы нет.
final class CampaignUnavailable extends CampaignState {
  /// Создаёт состояние.
  const CampaignUnavailable();
}

/// Тропа готова.
final class CampaignReady extends CampaignState {
  /// Создаёт состояние; [pendingReward] — награда, которую игрок ещё не видел (стартовый набор при входе).
  const CampaignReady(this.overview, {this.pendingReward});

  /// Что показывает тропа.
  final CampaignOverview overview;

  /// Победа, чью награду нужно показать до тропы; `null`, если показывать нечего.
  final CampaignWon? pendingReward;

  /// Копия с другой тропой, награда остаётся.
  CampaignReady withOverview(CampaignOverview overview) => CampaignReady(overview, pendingReward: pendingReward);

  /// Копия без награды: игрок её посмотрел.
  CampaignReady withoutReward() => CampaignReady(overview);
}
