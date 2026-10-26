import 'package:drift/drift.dart';
import 'package:gwent/src/core/database/app_database.steps.dart';
import 'package:gwent/src/core/database/tables/campaign_tables.dart';
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
@DriftDatabase(
  tables: [Decks, DeckCards, ActiveDecks, Settings, MatchRecords, MatchReplays, OwnedCardEntries, CampaignProgress],
)
class AppDatabase extends _$AppDatabase {
  /// Открывает базу через исполнитель запросов [e]: файл на устройстве или память в тестах.
  AppDatabase(super.e);

  @override
  int get schemaVersion => 5;

  /// Шаги обновления по версиям. Отдельно от [migration], чтобы тест мог подставить сбойный шаг.
  @visibleForTesting
  OnUpgrade get upgradeSteps => stepByStep(
    // Версия 2: активная колода фракции.
    from1To2: (m, schema) => m.createTable(schema.activeDecks),
    // Версия 3: реплеи партий. Прежние партии остаются сводкой (`has_replay` = 0).
    from2To3: (m, schema) async {
      await m.addColumn(schema.matchRecords, schema.matchRecords.hasReplay);
      await m.createTable(schema.matchReplays);
    },
    // Версия 4: пас по умолчанию держат, а не подтверждают диалогом. Таблицы те же, меняется смысл хранимой настройки:
    // раньше по умолчанию было «подтверждать» и хранилось только отключение, теперь наоборот. Ключ удаляется у всех,
    // и «Подтверждать пас» у каждого выключено; кто захочет диалог, включит его в настройках.
    from3To4: (m, schema) async {
      await m.database.customStatement("DELETE FROM settings WHERE key = 'confirm_pass'");
    },
    // Версия 5: коллекция и прогресс кампании (ADR 0033). Только новые таблицы: колоды, история и настройки не меняются,
    // открытых карт у обновившегося игрока нет, кампания начинается с нуля.
    from4To5: (m, schema) async {
      await m.createTable(schema.ownedCards);
      await m.createTable(schema.campaignProgress);
    },
  );

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // Создание и обновление идут одной транзакцией: сбой посреди шага не оставляет базу на полпути
    // и не сдвигает версию, а следующая сборка с исправленным шагом открывает прежние данные (ADR 0024).
    onCreate: (m) => transaction(m.createAll),
    onUpgrade: (m, from, to) => transaction(() async {
      await upgradeSteps(m, from, to);
      // Версию пишем в той же транзакции (в SQLite она транзакционна): иначе обрыв процесса между коммитом
      // и записью версии повторил бы уже выполненные шаги.
      await customStatement('PRAGMA user_version = $to');
    }),
    beforeOpen: (details) async {
      // SQLite по умолчанию не проверяет внешние ключи, а каскадное удаление карт колоды на них держится.
      // Включается после миграции: внутри транзакции этот PRAGMA не действует.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
