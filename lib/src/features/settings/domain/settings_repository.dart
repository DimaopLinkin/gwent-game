import 'package:gwent/src/features/settings/domain/app_settings.dart';

/// Хранилище настроек игрока.
abstract interface class SettingsRepository {
  /// Текущие настройки; поток выдаёт новое значение после каждого сохранения.
  Stream<AppSettings> watch();

  /// Сохраняет настройки целиком.
  Future<void> save(AppSettings settings);
}
