import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/settings/application/save_settings.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';

import '../../../support/fakes.dart';

void main() {
  late InMemorySettingsRepository repository;
  late SaveSettings saveSettings;

  setUp(() {
    repository = InMemorySettingsRepository();
    saveSettings = SaveSettings(repository);
  });

  test('имя игрока сохраняется без пробелов по краям', () async {
    await saveSettings(const AppSettings(playerName: '  Геральт '));

    expect(repository.saved, const AppSettings(playerName: 'Геральт'));
  });

  test('пустое имя сохраняется как отсутствующее', () async {
    await saveSettings(const AppSettings(playerName: '   '));

    expect(repository.saved.playerName, isNull);
  });
}
