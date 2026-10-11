import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/settings/data/drift_settings_repository.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';

import '../../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsRepository repository;

  setUp(() {
    db = openTestDatabase();
    repository = DriftSettingsRepository(db);
  });

  tearDown(() => db.close());

  test('без сохранённых значений действуют значения по умолчанию', () async {
    expect(await repository.watch().first, const AppSettings());
  });

  test('сохранённые настройки читаются, а null возвращает значение по умолчанию', () async {
    await repository.save(const AppSettings(playerName: 'Геральт'));
    expect(await repository.watch().first, const AppSettings(playerName: 'Геральт'));

    await repository.save(const AppSettings());
    expect(await repository.watch().first, const AppSettings());
    expect(await db.select(db.settings).get(), isEmpty);
  });
}
