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

  test('миграция с версии 1 сохраняет данные всех таблиц', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase
      ..execute("INSERT INTO decks VALUES ('d1', 'Моя колода', 'faction', 'leader', '2026-10-11T12:00:00.000Z')")
      ..execute("INSERT INTO deck_cards VALUES ('d1', 'card', 3)")
      ..execute("INSERT INTO settings VALUES ('music_volume', '40')")
      ..execute(
        "INSERT INTO match_records VALUES ('m1', 'bot', 'f1', 'f2', 'Геральт', 'win', 2, 1, '2026-10-11T13:00:00.000Z')",
      );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    final deck = await db.select(db.decks).getSingle();
    expect((deck.id, deck.name, deck.factionId, deck.leaderId), ('d1', 'Моя колода', 'faction', 'leader'));
    expect(deck.updatedAt.toUtc(), DateTime.utc(2026, 10, 11, 12));
    final card = await db.select(db.deckCards).getSingle();
    expect((card.deckId, card.cardId, card.copies), ('d1', 'card', 3));
    final setting = await db.select(db.settings).getSingle();
    expect((setting.key, setting.value), ('music_volume', '40'));
    final record = await db.select(db.matchRecords).getSingle();
    expect((record.id, record.opponentName, record.roundsWon, record.roundsLost), ('m1', 'Геральт', 2, 1));
    expect(record.finishedAt.toUtc(), DateTime.utc(2026, 10, 11, 13));
    expect(await db.select(db.activeDecks).get(), isEmpty);
  });

  test('сбой шага откатывает всё обновление и не двигает версию', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute("INSERT INTO settings VALUES ('music_volume', '40')");

    final db = _FailingUpgradeDatabase(schema.newConnection());
    addTearDown(db.close);

    await expectLater(db.select(db.settings).get(), throwsA(isA<StateError>()));

    final columns = schema.rawDatabase.select('PRAGMA table_info(settings)').map((row) => row['name']);
    expect(columns, ['key', 'value']);
    expect(schema.rawDatabase.select("SELECT name FROM sqlite_master WHERE name = 'active_decks'"), isEmpty);
    expect(schema.rawDatabase.select('PRAGMA user_version').single['user_version'], 1);
    expect(schema.rawDatabase.select('SELECT value FROM settings').single['value'], '40');
  });
}

/// База, у которой шаг обновления меняет схему и затем падает: проверяет, что обновление идёт одной транзакцией.
class _FailingUpgradeDatabase extends AppDatabase {
  _FailingUpgradeDatabase(super.e);

  @override
  OnUpgrade get upgradeSteps => (m, from, to) async {
    await m.createTable(activeDecks);
    await customStatement('ALTER TABLE settings ADD COLUMN extra TEXT');
    throw StateError('сбой шага');
  };
}
