import 'package:gwent/src/features/settings/domain/settings_repository.dart';

/// Сценарий: следить за тем, прошёл ли игрок «Первую партию» (ADR 0034); меню по нему показывает марку «Новое».
final class WatchFirstMatchPassed {
  /// Создаёт сценарий.
  const WatchFirstMatchPassed(this._settings);

  final SettingsRepository _settings;

  /// Поток: `true`, когда «Первая партия» пройдена; выдаёт новое значение, только когда оно изменилось.
  Stream<bool> call() => _settings.watch().map((settings) => settings.firstMatchPassed).distinct();
}
