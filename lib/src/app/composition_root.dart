import 'package:flutter/services.dart';
import 'package:gwent/src/app/app_dependencies.dart';
import 'package:gwent/src/core/data/package_app_info.dart';
import 'package:gwent/src/core/data/secure_seed_generator.dart';
import 'package:gwent/src/core/data/system_clock.dart';
import 'package:gwent/src/core/data/uuid_id_generator.dart';
import 'package:gwent/src/core/database/app_database.dart';
import 'package:gwent/src/core/database/app_database_connection.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/data/drift_deck_repository.dart';
import 'package:gwent/src/features/lobby/data/bonsoir_service_directory.dart';
import 'package:gwent/src/features/lobby/data/device_network_access.dart';
import 'package:gwent/src/features/lobby/data/game_ad_record.dart';
import 'package:gwent/src/features/lobby/data/lan_lobby.dart';
import 'package:gwent/src/features/lobby/data/online/drift_online_session_store.dart';
import 'package:gwent/src/features/lobby/data/online/online_config.dart';
import 'package:gwent/src/features/lobby/data/online/online_lobby.dart';
import 'package:gwent/src/features/lobby/data/online/supabase_online_rooms.dart';
import 'package:gwent/src/features/match_history/data/drift_match_history_repository.dart';
import 'package:gwent/src/features/settings/data/drift_settings_repository.dart';
import 'package:gwent/src/features/sound/data/audioplayers_music_output.dart';
import 'package:gwent/src/features/sound/data/audioplayers_sound_output.dart';
import 'package:gwent_net/gwent_net.dart' show SystemScheduler;

/// Точка сборки: единственное место, где интерфейсы связываются с реализациями.
///
/// База открывается лениво, при первом запросе, поэтому сборка синхронная и не задерживает первый кадр.
/// База живёт столько же, сколько процесс приложения, и не закрывается явно: процесс завершает ОС.
AppDependencies createAppDependencies() {
  final database = AppDatabase(openAppDatabaseConnection());
  const clock = SystemClock();
  return AppDependencies(
    contentSource: AssetContentSource.basePack(rootBundle),
    appInfo: const PackageAppInfo(),
    deckRepository: DriftDeckRepository(database),
    settingsRepository: DriftSettingsRepository(database),
    matchHistoryRepository: DriftMatchHistoryRepository(database),
    clock: clock,
    idGenerator: const UuidIdGenerator(),
    seedGenerator: SecureSeedGenerator(),
    gameLobby: LanLobby(directory: const BonsoirServiceDirectory(type: GameAdRecord.serviceType)),
    // Клиент Supabase создаётся при первом обращении к комнатам, поэтому сборка остаётся синхронной и лёгкой.
    onlineLobby: OnlineLobby(
      rooms: SupabaseOnlineRooms(
        config: OnlineConfig.gwentMobile,
        sessions: DriftOnlineSessionStore(database),
        clock: clock,
      ),
      scheduler: const SystemScheduler(),
      clock: clock,
    ),
    networkAccess: DeviceNetworkAccess(),
    soundOutput: AudioplayersSoundOutput(),
    musicOutput: AudioplayersMusicOutput(),
  );
}
