import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';

/// Сценарий: следить за настройками игрока.
final class WatchSettings {
  /// Создаёт сценарий над [repository].
  const WatchSettings(this._repository);

  final SettingsRepository _repository;

  /// Текущие настройки и их изменения.
  Stream<AppSettings> call() => _repository.watch();
}
