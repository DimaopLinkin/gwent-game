import 'package:gwent/src/features/settings/domain/settings_repository.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;

/// Сценарий: уровень сложности бота, выбранный игроком в прошлый раз.
final class LoadBotDifficulty {
  /// Создаёт сценарий над [repository].
  const LoadBotDifficulty(this._repository);

  final SettingsRepository _repository;

  /// Сохранённый уровень; «нормальный», пока игрок не выбирал.
  Future<BotDifficulty> call() async => (await _repository.watch().first).botDifficulty;
}
