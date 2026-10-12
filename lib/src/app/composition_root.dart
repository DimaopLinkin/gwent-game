import 'package:flutter/services.dart';
import 'package:gwent/src/app/app_dependencies.dart';
import 'package:gwent/src/core/data/system_clock.dart';
import 'package:gwent/src/core/data/uuid_id_generator.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/core/database/app_database_connection.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/data/drift_deck_repository.dart';
import 'package:gwent/src/features/match_history/data/drift_match_history_repository.dart';
import 'package:gwent/src/features/settings/data/drift_settings_repository.dart';

/// Точка сборки: единственное место, где интерфейсы связываются с реализациями.
///
/// База открывается лениво, при первом запросе, поэтому сборка синхронная и не задерживает первый кадр.
/// База живёт столько же, сколько процесс приложения, и не закрывается явно: процесс завершает ОС.
AppDependencies createAppDependencies() {
  final database = AppDatabase(openAppDatabaseConnection());
  return AppDependencies(
    contentSource: AssetContentSource.basePack(rootBundle),
    deckRepository: DriftDeckRepository(database),
    settingsRepository: DriftSettingsRepository(database),
    matchHistoryRepository: DriftMatchHistoryRepository(database),
    clock: const SystemClock(),
    idGenerator: const UuidIdGenerator(),
  );
}
