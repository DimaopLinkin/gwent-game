import 'package:drift/drift.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/collection/data/drift_collection_repository.dart';

/// Прогресс кампании в таблице `campaign_progress` базы Drift: по строке на пройденный узел.
final class DriftCampaignRepository implements CampaignRepository {
  /// Создаёт репозиторий над [database].
  DriftCampaignRepository(this._db) : _collection = DriftCollectionRepository(_db);

  final AppDatabase _db;
  final DriftCollectionRepository _collection;

  @override
  Future<Map<String, NodeProgress>> load() async => _toProgress(await _db.select(_db.campaignProgress).get());

  @override
  Stream<Map<String, NodeProgress>> watch() => _db.select(_db.campaignProgress).watch().map(_toProgress);

  @override
  Future<void> recordWin(NodeWin win) => _db.transaction(() async {
    final existing = await (_db.select(
      _db.campaignProgress,
    )..where((row) => row.nodeId.equals(win.nodeId))).getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.campaignProgress)
          .insert(
            CampaignProgressCompanion.insert(
              nodeId: win.nodeId,
              wins: 1,
              firstWinAt: win.at,
              bonusClaimedAt: Value(win.claimsBonus ? win.at : null),
            ),
          );
    } else {
      await (_db.update(_db.campaignProgress)..where((row) => row.nodeId.equals(win.nodeId))).write(
        CampaignProgressCompanion(
          wins: Value(existing.wins + 1),
          bonusClaimedAt: win.claimsBonus && existing.bonusClaimedAt == null ? Value(win.at) : const Value.absent(),
        ),
      );
    }
    // Награда в той же транзакции: ошибка здесь откатывает и пометку об узле.
    if (win.grants.isNotEmpty) await _collection.grant(win.grants);
  });

  Map<String, NodeProgress> _toProgress(List<CampaignProgressRow> rows) => {
    for (final row in rows)
      row.nodeId: NodeProgress(
        nodeId: row.nodeId,
        wins: row.wins,
        firstWinAt: row.firstWinAt,
        bonusClaimedAt: row.bonusClaimedAt,
      ),
  };
}
