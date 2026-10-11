import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/database/app_database.dart';

import 'generated/schema.dart';

/// Миграции базы пользовательских данных.
///
/// Схемы прежних версий лежат в `drift_schemas/app_database/`, тестовые базы по ним собирает `setup.sh`.
void main() {
  // Тест открывает базы разных версий над одним исполнителем запросов; для миграций это ожидаемо.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('последняя сохранённая схема соответствует текущей версии базы', () async {
    final schema = await verifier.schemaAt(GeneratedHelper.versions.last);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    expect(db.schemaVersion, GeneratedHelper.versions.last);
    await verifier.migrateAndValidate(db, db.schemaVersion);
  });

  for (final from in GeneratedHelper.versions.where((version) => version < GeneratedHelper.versions.last)) {
    test('миграция с версии $from до последней даёт текущую схему', () async {
      final schema = await verifier.schemaAt(from);
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, db.schemaVersion);
    });
  }
}
