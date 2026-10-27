import 'package:gwent/src/features/campaign/application/get_campaign_deck.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/domain/campaign_path.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/campaign/domain/campaign_totals.dart';
import 'package:gwent/src/features/collection/domain/collection_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:meta/meta.dart';

/// Всё, что показывает тропа: сама тропа, колода кампании и сколько карт открыто.
@immutable
final class CampaignOverview {
  /// Создаёт обзор.
  const CampaignOverview({
    required this.data,
    required this.path,
    required this.deck,
    required this.opened,
    required this.total,
  });

  /// Каталог и пакет с текстами.
  final CampaignData data;

  /// Тропа с состояниями узлов.
  final CampaignPath path;

  /// Колода, с которой игрок идёт в бой; `null`, если годной нет.
  final Deck? deck;

  /// Открыто копий карт и лидеров.
  final int opened;

  /// Всего копий карт и лидеров в пакете.
  final int total;
}

/// Сценарий: обзор кампании для тропы.
final class LoadCampaignOverview {
  /// Создаёт сценарий.
  const LoadCampaignOverview(this._campaign, this._repository, this._collection, this._deck);

  final LoadCampaign _campaign;
  final CampaignRepository _repository;
  final CollectionRepository _collection;
  final GetCampaignDeck _deck;

  /// Обзор сейчас; `null`, если каталога кампании нет.
  Future<CampaignOverview?> call() async {
    final data = await _campaign();
    if (data == null) return null;
    final owned = await _collection.load();
    return CampaignOverview(
      data: data,
      path: CampaignPath.build(data.catalog, await _repository.load()),
      deck: await _deck(),
      opened: owned.total,
      total: totalCardCopies(data.pack.rules),
    );
  }
}
