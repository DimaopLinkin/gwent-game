import 'package:gwent/src/features/settings/domain/settings_repository.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;

/// Сценарий: запомнить уровень сложности бота, с которым игрок начал партию.
final class SaveBotDifficulty {
  /// Создаёт сценарий над [repository].
  const SaveBotDifficulty(this._repository);

  final SettingsRepository _repository;

  /// Сохраняет [difficulty], остальные настройки не меняет.
  Future<void> call(BotDifficulty difficulty) async {
    final settings = await _repository.watch().first;
    if (settings.botDifficulty == difficulty) return;
    await _repository.save(settings.copyWith(botDifficulty: difficulty));
  }
}
