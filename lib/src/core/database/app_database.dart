import 'package:drift/drift.dart';
import 'package:gwent/src/core/database/app_database.steps.dart';
import 'package:gwent/src/core/database/tables/decks_table.dart';
import 'package:gwent/src/core/database/tables/match_records_table.dart';
import 'package:gwent/src/core/database/tables/settings_table.dart';

part 'app_database.g.dart';

/// База пользовательских данных: колоды, настройки, история партий.
///
/// Изменение схемы: поправить таблицы, увеличить [schemaVersion], запустить `tools/scripts/setup.sh`
/// (он сохранит схему новой версии в `drift_schemas/` и соберёт шаги миграции), дописать шаг в [migration]
/// и закоммитить новый файл схемы. Тест миграций проверяет переход со всех прежних версий.
@DriftDatabase(tables: [Decks, DeckCards, ActiveDecks, Settings, MatchRecords])
class AppDatabase extends _$AppDatabase {
  /// Открывает базу через исполнитель запросов [e]: файл на устройстве или память в тестах.
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      // Версия 2: активная колода фракции.
      from1To2: (m, schema) => m.createTable(schema.activeDecks),
    ),
    beforeOpen: (details) async {
      // SQLite по умолчанию не проверяет внешние ключи, а каскадное удаление карт колоды на них держится.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
