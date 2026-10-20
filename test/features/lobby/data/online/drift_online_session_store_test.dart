import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/features/lobby/data/online/drift_online_session_store.dart';
import 'package:gwent/src/features/settings/data/drift_settings_repository.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';

import '../../../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftOnlineSessionStore store;

  setUp(() {
    db = openTestDatabase();
    store = DriftOnlineSessionStore(db);
  });

  tearDown(() => db.close());

  test('без записи сессии нет', () async {
    expect(await store.read(), isNull);
  });

  test('сессия записывается, заменяется и забывается', () async {
    await store.write('{"a":1}');
    expect(await store.read(), '{"a":1}');

    await store.write('{"a":2}');
    expect(await store.read(), '{"a":2}');
    expect(await db.select(db.settings).get(), hasLength(1));

    await store.clear();
    expect(await store.read(), isNull);
    await store.clear();
  });

  test('сохранение настроек не стирает сессию, а сессия не попадает в настройки', () async {
    await store.write('token');
    final settings = DriftSettingsRepository(db);

    await settings.save(const AppSettings(playerName: 'Цири'));
    expect(await store.read(), 'token');

    await settings.save(const AppSettings());
    expect(await store.read(), 'token');
    expect(await settings.watch().first, const AppSettings());
  });
}
