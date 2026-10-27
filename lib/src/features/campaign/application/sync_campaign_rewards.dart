import 'dart:math' as math;

import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/campaign/domain/card_copy_limit.dart';
import 'package:gwent/src/features/collection/domain/collection_repository.dart';

/// Сценарий: сверить открытые карты с наградами пройденных узлов (ADR 0033).
///
/// Раздача наград меняется вместе с каталогом кампании. Игрок, прошедший узел до обновления, не получает новых копий
/// задним числом (награда первой победы выдаётся один раз), поэтому при входе в тропу выдаётся недостающее: для каждой
/// карты считается, сколько копий дают награды пройденных узлов (и награды за условие, если она получена), и
/// доводится до этого числа, но не выше `count` карты. Лишнее не отнимается. Повторная сверка ничего не выдаёт.
final class SyncCampaignRewards {
  /// Создаёт сценарий.
  const SyncCampaignRewards(this._campaign, this._progress, this._collection);

  final LoadCampaign _campaign;
  final CampaignRepository _progress;
  final CollectionRepository _collection;

  /// Выдаёт недостающие копии. Возвращает, сколько копий добавлено (ноль, если всё на месте или каталога нет).
  Future<int> call() async {
    final data = await _campaign();
    if (data == null) return 0;
    final progress = await _progress.load();
    if (progress.isEmpty) return 0;
    final owned = await _collection.load();
    final rules = data.pack.rules;

    final earned = <String, int>{};
    for (final node in data.catalog.nodes) {
      final done = progress[node.id];
      if (done == null) continue;
      final bonus = node.bonus;
      for (final grant in [...node.reward, if (bonus != null && done.bonusClaimed) ...bonus.reward]) {
        earned.update(grant.cardId, (copies) => copies + grant.copies, ifAbsent: () => grant.copies);
      }
    }

    final missing = <String, int>{};
    for (final MapEntry(key: cardId, value: copies) in earned.entries) {
      final target = math.min(copies, cardCopyLimit(rules, cardId));
      final lack = target - owned.copiesOf(cardId);
      if (lack > 0) missing[cardId] = lack;
    }
    if (missing.isEmpty) return 0;
    await _collection.grant(missing);
    return missing.values.fold<int>(0, (sum, copies) => sum + copies);
  }
}
