import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';

/// Настройки в таблице «ключ — значение» базы Drift.
///
/// Ключи ниже хранятся в базе: переименование ключа требует миграции.
final class DriftSettingsRepository implements SettingsRepository {
  /// Создаёт репозиторий над [database].
  const DriftSettingsRepository(this._db);

  static const String _playerNameKey = 'player_name';

  final AppDatabase _db;

  @override
  Stream<AppSettings> watch() => _db.select(_db.settings).watch().map(_toSettings);

  @override
  Future<void> save(AppSettings settings) => _db.transaction(() async {
    await _put(_playerNameKey, settings.playerName);
  });

  /// Записывает значение по ключу; `null` удаляет ключ, и настройка возвращается к значению по умолчанию.
  Future<void> _put(String key, String? value) async {
    if (value == null) {
      await (_db.delete(_db.settings)..where((row) => row.key.equals(key))).go();
    } else {
      await _db.into(_db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
    }
  }

  AppSettings _toSettings(List<SettingRow> rows) {
    final values = {for (final row in rows) row.key: row.value};
    return AppSettings(playerName: values[_playerNameKey]);
  }
}
