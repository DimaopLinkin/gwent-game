import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/settings/application/load_bot_difficulty.dart';
import 'package:gwent/src/features/settings/application/save_bot_difficulty.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;

import '../../../support/fakes.dart';

void main() {
  late InMemorySettingsRepository repository;

  setUp(() => repository = InMemorySettingsRepository());

  test('пока игрок не выбирал, уровень нормальный', () async {
    expect(await LoadBotDifficulty(repository)(), BotDifficulty.normal);
  });

  test('сохранённый уровень читается, остальные настройки не меняются', () async {
    repository.saved = const AppSettings(playerName: 'Геральт', hints: false);

    await SaveBotDifficulty(repository)(BotDifficulty.hard);

    expect(await LoadBotDifficulty(repository)(), BotDifficulty.hard);
    expect(repository.saved, const AppSettings(playerName: 'Геральт', hints: false, botDifficulty: BotDifficulty.hard));
  });
}
