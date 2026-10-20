import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/lobby/domain/online_session_store.dart';

/// Сессия игрока для игры через интернет в таблице настроек базы Drift (ADR 0026).
///
/// Это один ключ в существующей таблице «ключ — значение», схема базы не меняется (ADR 0003, 0024). Ключ хранится в базе:
/// переименование требует миграции. Строка — непрозрачная сессия клиента сервера.
final class DriftOnlineSessionStore implements OnlineSessionStore {
  /// Создаёт хранилище над [database].
  const DriftOnlineSessionStore(this._db);

  static const String _key = 'online_session';

  final AppDatabase _db;

  @override
  Future<String?> read() async {
    final row = await (_db.select(_db.settings)..where((row) => row.key.equals(_key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> write(String session) =>
      _db.into(_db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: _key, value: session));

  @override
  Future<void> clear() => (_db.delete(_db.settings)..where((row) => row.key.equals(_key))).go();
}
