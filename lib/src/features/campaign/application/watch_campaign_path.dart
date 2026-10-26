import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/domain/campaign_path.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';

/// Сценарий: тропа кампании, которая обновляется вместе с прогрессом.
final class WatchCampaignPath {
  /// Создаёт сценарий.
  const WatchCampaignPath(this._campaign, this._repository);

  final LoadCampaign _campaign;
  final CampaignRepository _repository;

  /// Тропа сейчас и после каждого изменения прогресса. Пустой поток, если каталога кампании нет.
  Stream<CampaignPath> call() async* {
    final data = await _campaign();
    if (data == null) return;
    yield* _repository.watch().map((progress) => CampaignPath.build(data.catalog, progress));
  }
}
