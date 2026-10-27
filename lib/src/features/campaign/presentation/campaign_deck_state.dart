import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/domain/campaign_deck.dart';
import 'package:gwent_content/gwent_content.dart' show CampaignNode;
import 'package:meta/meta.dart';

/// Состояние экрана «Колода для боя».
@immutable
sealed class CampaignDeckState {
  const CampaignDeckState();
}

/// Колоды загружаются.
final class CampaignDeckLoading extends CampaignDeckState {
  /// Создаёт состояние.
  const CampaignDeckLoading();
}

/// Колоды или каталог не прочитались.
final class CampaignDeckFailed extends CampaignDeckState {
  /// Создаёт состояние.
  const CampaignDeckFailed();
}

/// Колоды готовы к выбору.
final class CampaignDeckLoaded extends CampaignDeckState {
  /// Создаёт состояние; [selectedId] — выбранная колода, [node] — узел, в бой на который идёт игрок (`null` — колоду
  /// выбирают заранее, с тропы).
  CampaignDeckLoaded({required this.data, required List<CampaignDeck> decks, required this.selectedId, this.node})
    : decks = List.unmodifiable(decks);

  /// Каталог и пакет с текстами.
  final CampaignData data;

  /// Колоды игрока с оценкой для кампании: годные первыми.
  final List<CampaignDeck> decks;

  /// Выбранная годная колода или `null`.
  final String? selectedId;

  /// Узел, в который идёт игрок.
  final CampaignNode? node;

  /// Есть хотя бы одна годная колода.
  bool get hasReady => decks.any((entry) => entry.isReady);

  /// Копия с другим выбором.
  CampaignDeckLoaded select(String id) => CampaignDeckLoaded(data: data, decks: decks, selectedId: id, node: node);
}
