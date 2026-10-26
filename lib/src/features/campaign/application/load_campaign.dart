import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent_content/gwent_content.dart';
import 'package:meta/meta.dart';

/// Каталог кампании вместе с пакетом, из которого он взят: пакет даёт тексты и правила карт.
@immutable
final class CampaignData {
  /// Создаёт данные кампании.
  const CampaignData({required this.catalog, required this.pack});

  /// Каталог.
  final CampaignCatalog catalog;

  /// Пакет контента.
  final ContentPack pack;

  /// Текст по ключу пакета (названия глав, имена соперников, темы колод).
  String text(String key) => pack.text(key);
}

/// Сценарий: каталог кампании из активного пакета контента.
final class LoadCampaign {
  /// Создаёт сценарий.
  const LoadCampaign(this._content);

  final LoadGameContent _content;

  /// Каталог кампании; `null`, если пакет не загрузился или в нём нет каталога (кампанию тогда не показывают).
  Future<CampaignData?> call() async => switch (await _content()) {
    GameContentReady(:final content) => switch (content.pack.campaign) {
      final catalog? => CampaignData(catalog: catalog, pack: content.pack),
      null => null,
    },
    GameContentRejected() => null,
  };
}
