import 'package:gwent/src/features/settings/domain/settings_repository.dart';

/// Сценарий: запомнить, что игрок прошёл «Первую партию» (ADR 0034).
final class MarkFirstMatchPassed {
  /// Создаёт сценарий.
  const MarkFirstMatchPassed(this._settings);

  final SettingsRepository _settings;

  /// Записывает прохождение; повторный вызов ничего не меняет.
  Future<void> call() async {
    final current = await _settings.watch().first;
    if (!current.firstMatchPassed) await _settings.save(current.copyWith(firstMatchPassed: true));
  }
}
