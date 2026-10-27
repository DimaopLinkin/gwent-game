import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/domain/campaign_path.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/campaign/domain/campaign_summary.dart';

/// Сценарий: сводка кампании для главного меню, которая обновляется вместе с прогрессом.
final class WatchCampaignSummary {
  /// Создаёт сценарий.
  const WatchCampaignSummary(this._campaign, this._repository);

  final LoadCampaign _campaign;
  final CampaignRepository _repository;

  /// Сводка сейчас и после каждого изменения прогресса; один раз `null`, если каталога кампании нет (кнопки нет).
  Stream<CampaignSummary?> call() async* {
    final data = await _campaign();
    if (data == null) {
      yield null;
      return;
    }
    yield* _repository.watch().map((progress) {
      final path = CampaignPath.build(data.catalog, progress);
      final chapter = path.currentChapter ?? path.chapters.first;
      return CampaignSummary(
        chapterNumber: chapter.chapter.number,
        chapterName: data.text(chapter.chapter.nameKey),
        passed: chapter.passedCount,
        total: chapter.totalCount,
        started: path.started,
      );
    });
  }
}
