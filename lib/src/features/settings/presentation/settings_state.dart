import 'package:gwent/src/features/settings/domain/about_info.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:meta/meta.dart';

/// Состояние проверки обновления набора карт на экране настроек.
enum ContentUpdateStatus {
  /// Игрок ещё не нажимал «Проверить обновление».
  idle,

  /// Проверка идёт, кнопка погашена.
  checking,

  /// Проверка закончилась: набор актуален.
  upToDate,

  /// Проверить не удалось.
  failed,
}

/// Состояние экрана настроек.
@immutable
sealed class SettingsState {
  const SettingsState();
}

/// Настройки читаются.
final class SettingsLoading extends SettingsState {
  /// Создаёт состояние.
  const SettingsLoading();
}

/// Настройки не прочитались.
final class SettingsFailed extends SettingsState {
  /// Создаёт состояние.
  const SettingsFailed();
}

/// Настройки прочитаны и показаны.
final class SettingsLoaded extends SettingsState {
  /// Создаёт состояние.
  const SettingsLoaded({required this.settings, required this.about, this.update = ContentUpdateStatus.idle});

  /// Настройки игрока.
  final AppSettings settings;

  /// Версии для групп «Данные карт» и «О приложении».
  final AboutInfo about;

  /// Как идёт проверка обновления набора карт.
  final ContentUpdateStatus update;

  /// Копия с другими значениями.
  SettingsLoaded copyWith({AppSettings? settings, ContentUpdateStatus? update}) =>
      SettingsLoaded(settings: settings ?? this.settings, about: about, update: update ?? this.update);
}
