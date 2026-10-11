import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';

/// Сценарий: сохранить настройки игрока.
final class SaveSettings {
  /// Создаёт сценарий над [repository].
  const SaveSettings(this._repository);

  final SettingsRepository _repository;

  /// Сохраняет [settings]. Пустое или состоящее из пробелов имя игрока сохраняется как отсутствующее.
  Future<void> call(AppSettings settings) {
    final name = settings.playerName?.trim();
    return _repository.save(settings.withPlayerName(name == null || name.isEmpty ? null : name));
  }
}
