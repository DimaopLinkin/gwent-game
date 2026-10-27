import 'package:meta/meta.dart';

/// Прогресс игрока по одному узлу кампании (ADR 0033). Узел без записи не пройден.
@immutable
final class NodeProgress {
  /// Создаёт запись о пройденном узле.
  const NodeProgress({required this.nodeId, required this.wins, required this.firstWinAt, this.bonusClaimedAt});

  /// Идентификатор узла из каталога.
  final String nodeId;

  /// Сколько раз узел выигран, не меньше одного.
  final int wins;

  /// Момент первой победы (UTC).
  final DateTime firstWinAt;

  /// Момент получения дополнительной награды за условие (UTC) или `null`, пока она не получена.
  final DateTime? bonusClaimedAt;

  /// Награда за условие уже получена.
  bool get bonusClaimed => bonusClaimedAt != null;

  @override
  bool operator ==(Object other) =>
      other is NodeProgress &&
      other.nodeId == nodeId &&
      other.wins == wins &&
      other.firstWinAt == firstWinAt &&
      other.bonusClaimedAt == bonusClaimedAt;

  @override
  int get hashCode => Object.hash(nodeId, wins, firstWinAt, bonusClaimedAt);

  @override
  String toString() => 'NodeProgress($nodeId, побед: $wins, награда за условие: $bonusClaimed)';
}

/// Победа в узле, которую нужно записать вместе с наградой.
@immutable
final class NodeWin {
  /// Создаёт запись о победе.
  NodeWin({required this.nodeId, required this.at, Map<String, int> grants = const {}, this.claimsBonus = false})
    : grants = Map.unmodifiable(grants);

  /// Выигранный узел.
  final String nodeId;

  /// Момент победы (UTC).
  final DateTime at;

  /// Карты и лидеры, которые открываются этой победой: UUID и сколько копий прибавить.
  final Map<String, int> grants;

  /// Победа получает дополнительную награду за условие: в записи узла она помечается полученной.
  final bool claimsBonus;
}

/// Хранилище прогресса кампании (ADR 0033).
abstract interface class CampaignRepository {
  /// Прогресс по узлам сейчас: идентификатор узла → запись. Узлов без побед в словаре нет.
  Future<Map<String, NodeProgress>> load();

  /// Прогресс; поток выдаёт новый снимок после каждого изменения.
  Stream<Map<String, NodeProgress>> watch();

  /// Записывает победу: счёт побед узла растёт, а [NodeWin.grants] открываются в коллекции.
  ///
  /// Пометка об узле и награда пишутся в одной транзакции: победа не выдаёт карты дважды и не теряется. Если запись
  /// не удалась (в том числе из-за карты с числом копий меньше единицы), не меняется ничего, и ошибка уходит
  /// вызывающему. У первой победы момент [NodeWin.at] запоминается как `firstWinAt`; дополнительная награда
  /// ([NodeWin.claimsBonus]) уже полученная не перезаписывается.
  Future<void> recordWin(NodeWin win);

  /// Стирает кампанию: прогресс по всем узлам и открытые карты. Колоды игрока и настройки не трогает.
  ///
  /// Прогресс и карты стираются одной транзакцией: при ошибке остаётся всё как было.
  Future<void> reset();
}
