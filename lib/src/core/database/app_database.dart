import 'package:drift/drift.dart';
import 'package:gwent/src/core/database/app_database.steps.dart';
import 'package:gwent/src/core/database/tables/decks_table.dart';
import 'package:gwent/src/core/database/tables/match_records_table.dart';
import 'package:gwent/src/core/database/tables/settings_table.dart';
import 'package:meta/meta.dart';

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

  /// Шаги обновления по версиям. Отдельно от [migration], чтобы тест мог подставить сбойный шаг.
  @visibleForTesting
  OnUpgrade get upgradeSteps => stepByStep(
    // Версия 2: активная колода фракции.
    from1To2: (m, schema) => m.createTable(schema.activeDecks),
  );

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // Создание и обновление идут одной транзакцией: сбой посреди шага не оставляет базу на полпути
    // и не сдвигает версию, а следующая сборка с исправленным шагом открывает прежние данные (ADR 0024).
    onCreate: (m) => transaction(m.createAll),
    onUpgrade: (m, from, to) => transaction(() => upgradeSteps(m, from, to)),
    beforeOpen: (details) async {
      // SQLite по умолчанию не проверяет внешние ключи, а каскадное удаление карт колоды на них держится.
      // Включается после миграции: внутри транзакции этот PRAGMA не действует.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
