import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/settings/domain/animation_speed.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';

/// Настройки в таблице «ключ — значение» базы Drift.
///
/// Ключи и форматы значений ниже хранятся в базе: переименование ключа требует миграции. Булевы значения хранятся как
/// `true`/`false`, перечисления по имени, громкость целым, момент проверки набора как ISO 8601 в UTC. Нечитаемое
/// значение читается как значение по умолчанию.
final class DriftSettingsRepository implements SettingsRepository {
  /// Создаёт репозиторий над [database].
  const DriftSettingsRepository(this._db);

  static const String _playerNameKey = 'player_name';
  static const String _confirmPassKey = 'confirm_pass';
  static const String _animationSpeedKey = 'animation_speed';
  static const String _hintsKey = 'hints';
  static const String _musicVolumeKey = 'music_volume';
  static const String _effectsVolumeKey = 'effects_volume';
  static const String _contentCheckedAtKey = 'content_checked_at';
  static const String _localNetworkExplainedKey = 'local_network_explained';

  final AppDatabase _db;

  @override
  Stream<AppSettings> watch() => _db.select(_db.settings).watch().map(_toSettings);

  @override
  Future<void> save(AppSettings settings) => _db.transaction(() async {
    const defaults = AppSettings();
    await _put(_playerNameKey, settings.playerName);
    await _put(_confirmPassKey, _differs(settings.confirmPass, defaults.confirmPass));
    await _put(_animationSpeedKey, _differs(settings.animationSpeed, defaults.animationSpeed)?.name);
    await _put(_hintsKey, _differs(settings.hints, defaults.hints));
    await _put(_musicVolumeKey, _differs(settings.musicVolume, defaults.musicVolume));
    await _put(_effectsVolumeKey, _differs(settings.effectsVolume, defaults.effectsVolume));
    await _put(_contentCheckedAtKey, settings.contentCheckedAt?.toUtc().toIso8601String());
    await _put(_localNetworkExplainedKey, _differs(settings.localNetworkExplained, defaults.localNetworkExplained));
  });

  /// Значение в виде, пригодном для записи, или `null`, если оно равно значению по умолчанию и ключ не нужен.
  T? _differs<T>(T value, T byDefault) => value == byDefault ? null : value;

  /// Записывает значение по ключу; `null` удаляет ключ, и настройка возвращается к значению по умолчанию. Хранятся
  /// только значения, отличные от значений по умолчанию, поэтому смена умолчания касается всех, кто ничего не выбирал.
  Future<void> _put(String key, Object? value) async {
    if (value == null) {
      await (_db.delete(_db.settings)..where((row) => row.key.equals(key))).go();
    } else {
      await _db.into(_db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: '$value'));
    }
  }

  AppSettings _toSettings(List<SettingRow> rows) {
    final values = {for (final row in rows) row.key: row.value};
    const defaults = AppSettings();
    return AppSettings(
      playerName: values[_playerNameKey],
      confirmPass: _bool(values[_confirmPassKey]) ?? defaults.confirmPass,
      animationSpeed: AnimationSpeed.values.asNameMap()[values[_animationSpeedKey]] ?? defaults.animationSpeed,
      hints: _bool(values[_hintsKey]) ?? defaults.hints,
      musicVolume: _volume(values[_musicVolumeKey]) ?? defaults.musicVolume,
      effectsVolume: _volume(values[_effectsVolumeKey]) ?? defaults.effectsVolume,
      contentCheckedAt: DateTime.tryParse(values[_contentCheckedAtKey] ?? '')?.toUtc(),
      localNetworkExplained: _bool(values[_localNetworkExplainedKey]) ?? defaults.localNetworkExplained,
    );
  }

  bool? _bool(String? value) => switch (value) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  int? _volume(String? value) => int.tryParse(value ?? '')?.clamp(0, AppSettings.maxVolume);
}
