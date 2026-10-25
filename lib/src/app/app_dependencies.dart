import 'dart:math';

import 'package:gwent/src/core/domain/app_info.dart';
import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/core/domain/id_generator.dart';
import 'package:gwent/src/core/domain/seed_generator.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/application/delete_deck.dart';
import 'package:gwent/src/features/deck_builder/application/ensure_starter_decks.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/application/get_active_deck.dart';
import 'package:gwent/src/features/deck_builder/application/get_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/application/save_deck.dart';
import 'package:gwent/src/features/deck_builder/application/set_active_deck.dart';
import 'package:gwent/src/features/deck_builder/application/validate_deck.dart';
import 'package:gwent/src/features/deck_builder/application/watch_active_decks.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';
import 'package:gwent/src/features/haptics/application/play_haptic.dart';
import 'package:gwent/src/features/haptics/domain/haptic_output.dart';
import 'package:gwent/src/features/lobby/application/active_network_game.dart';
import 'package:gwent/src/features/lobby/application/discover_network_games.dart';
import 'package:gwent/src/features/lobby/application/host_network_game.dart';
import 'package:gwent/src/features/lobby/application/join_network_game.dart';
import 'package:gwent/src/features/lobby/application/link_timings.dart';
import 'package:gwent/src/features/lobby/application/load_network_setup.dart';
import 'package:gwent/src/features/lobby/application/network_readiness.dart';
import 'package:gwent/src/features/lobby/domain/game_lobby.dart';
import 'package:gwent/src/features/lobby/domain/network_access.dart';
import 'package:gwent/src/features/match/application/choose_opponent_deck.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/application/watch_match_history.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchMode;
import 'package:gwent/src/features/menu/application/load_menu.dart';
import 'package:gwent/src/features/replay/application/load_replay.dart';
import 'package:gwent/src/features/settings/application/check_content_update.dart';
import 'package:gwent/src/features/settings/application/load_about_info.dart';
import 'package:gwent/src/features/settings/application/load_bot_difficulty.dart';
import 'package:gwent/src/features/settings/application/save_bot_difficulty.dart';
import 'package:gwent/src/features/settings/application/save_settings.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';
import 'package:gwent/src/features/sound/application/background_music.dart';
import 'package:gwent/src/features/sound/application/play_sound.dart';
import 'package:gwent/src/features/sound/domain/music_output.dart';
import 'package:gwent/src/features/sound/domain/sound_output.dart';
import 'package:gwent_content/gwent_content.dart';
import 'package:gwent_net/gwent_net.dart' show Entropy, Scheduler, SecureEntropy, SystemScheduler;

/// Сценарии приложения, собранные над интерфейсами.
///
/// Знает только абстракции: реализации выбирает точка сборки (`composition_root.dart`), а тесты подставляют фейки.
/// Экраны получают отсюда сценарии через конструкторы своих держателей состояния (см. `router/app_router.dart`).
final class AppDependencies {
  /// Собирает сценарии.
  factory AppDependencies({
    required ContentSource contentSource,
    required AppInfo appInfo,
    required DeckRepository deckRepository,
    required SettingsRepository settingsRepository,
    required MatchHistoryRepository matchHistoryRepository,
    required Clock clock,
    required IdGenerator idGenerator,
    required SeedGenerator seedGenerator,
    required GameLobby gameLobby,
    required GameLobby onlineLobby,
    required NetworkAccess networkAccess,
    required SoundOutput soundOutput,
    required MusicOutput musicOutput,
    required HapticOutput hapticOutput,
    Random? random,
    Entropy? entropy,
    Scheduler scheduler = const SystemScheduler(),
    Duration botThinkTime = const Duration(milliseconds: 700),
  }) {
    final loadGameContent = LoadGameContent(contentSource);
    final deckRules = GameContentDeckRulesSource(loadGameContent);
    final createStarterDeck = CreateStarterDeck(deckRepository, clock, idGenerator);
    final deckSelectionLock = DeckSelectionLock();
    return AppDependencies._(
      appInfo: appInfo,
      loadGameContent: loadGameContent,
      deckRules: deckRules,
      deckRepository: deckRepository,
      createStarterDeck: createStarterDeck,
      deckSelectionLock: deckSelectionLock,
      settingsRepository: settingsRepository,
      matchHistoryRepository: matchHistoryRepository,
      clock: clock,
      idGenerator: idGenerator,
      seedGenerator: seedGenerator,
      gameLobby: gameLobby,
      onlineLobby: onlineLobby,
      networkAccess: networkAccess,
      soundOutput: soundOutput,
      musicOutput: musicOutput,
      hapticOutput: hapticOutput,
      random: random ?? Random(),
      entropy: entropy ?? SecureEntropy(),
      scheduler: scheduler,
      botThinkTime: botThinkTime,
    );
  }

  AppDependencies._({
    required AppInfo appInfo,
    required this.loadGameContent,
    required DeckRulesSource deckRules,
    required DeckRepository deckRepository,
    required CreateStarterDeck createStarterDeck,
    required DeckSelectionLock deckSelectionLock,
    required SettingsRepository settingsRepository,
    required MatchHistoryRepository matchHistoryRepository,
    required Clock clock,
    required IdGenerator idGenerator,
    required SeedGenerator seedGenerator,
    required GameLobby gameLobby,
    required GameLobby onlineLobby,
    required NetworkAccess networkAccess,
    required SoundOutput soundOutput,
    required MusicOutput musicOutput,
    required HapticOutput hapticOutput,
    required Random random,
    required Entropy entropy,
    required Scheduler scheduler,
    required Duration botThinkTime,
  }) : watchDecks = WatchDecks(deckRepository),
       saveDeck = SaveDeck(deckRepository, clock, idGenerator),
       deleteDeck = DeleteDeck(deckRepository),
       getDeck = GetDeck(deckRepository),
       loadDeckRules = LoadDeckRules(deckRules),
       validateDeck = ValidateDeck(deckRules),
       watchActiveDecks = WatchActiveDecks(deckRepository),
       setActiveDeck = SetActiveDeck(deckRepository, deckRules, deckSelectionLock),
       getActiveDeck = GetActiveDeck(deckRepository, deckRules, createStarterDeck, deckSelectionLock),
       ensureStarterDecks = EnsureStarterDecks(deckRepository, deckRules, createStarterDeck, deckSelectionLock),
       watchSettings = WatchSettings(settingsRepository),
       saveSettings = SaveSettings(settingsRepository),
       loadBotDifficulty = LoadBotDifficulty(settingsRepository),
       saveBotDifficulty = SaveBotDifficulty(settingsRepository),
       loadAboutInfo = LoadAboutInfo(appInfo, loadGameContent),
       checkContentUpdate = CheckContentUpdate(loadGameContent, clock),
       watchMatchHistory = WatchMatchHistory(matchHistoryRepository),
       recordMatch = RecordMatch(matchHistoryRepository, clock, idGenerator) {
    chooseOpponentDeck = ChooseOpponentDeck(deckRules, seedGenerator);
    loadMenu = LoadMenu(appInfo, loadGameContent, ensureStarterDecks);
    startMatch = StartMatch(loadGameContent, deckRepository, seedGenerator, botThinkTime: botThinkTime);
    recordFinishedMatch = RecordFinishedMatch(recordMatch);
    loadReplay = LoadReplay(matchHistoryRepository, loadGameContent);
    activeNetworkGame = ActiveNetworkGame();
    loadNetworkSetup = LoadNetworkSetup(loadGameContent, appInfo, watchSettings);
    hostNetworkGame = HostNetworkGame(loadNetworkSetup, gameLobby, activeNetworkGame, entropy, scheduler);
    joinNetworkGame = JoinNetworkGame(loadNetworkSetup, gameLobby, activeNetworkGame, scheduler);
    discoverNetworkGames = DiscoverNetworkGames(loadNetworkSetup, gameLobby);
    hostOnlineGame = HostNetworkGame(
      loadNetworkSetup,
      onlineLobby,
      activeNetworkGame,
      entropy,
      scheduler,
      timings: LinkTimings.internet,
      mode: MatchMode.server,
    );
    joinOnlineGame = JoinNetworkGame(
      loadNetworkSetup,
      onlineLobby,
      activeNetworkGame,
      scheduler,
      timings: LinkTimings.internet,
      mode: MatchMode.server,
    );
    networkReadiness = NetworkReadiness(networkAccess, settingsRepository);
    playHaptic = PlayHaptic(hapticOutput, watchSettings);
    playSound = PlaySound(soundOutput, watchSettings, haptic: playHaptic);
    backgroundMusic = BackgroundMusic(musicOutput, watchSettings, random);
  }

  /// Контент для партии и конструктора колод: пакет и справочник движка.
  final LoadGameContent loadGameContent;

  /// Список колод.
  final WatchDecks watchDecks;

  /// Сохранение колоды.
  final SaveDeck saveDeck;

  /// Удаление колоды.
  final DeleteDeck deleteDeck;

  /// Открывает сохранённую колоду для правки.
  final GetDeck getDeck;

  /// Правила сборки колод: фракции, лидеры, проверка.
  final LoadDeckRules loadDeckRules;

  /// Проверка колоды по правилам сборки.
  final ValidateDeck validateDeck;

  /// Выбор активных колод фракций.
  final WatchActiveDecks watchActiveDecks;

  /// Выбор активной колоды фракции.
  final SetActiveDeck setActiveDeck;

  /// Колода, с которой игрок идёт в партию за фракцию.
  final GetActiveDeck getActiveDeck;

  /// Стартовые колоды фракциям без колод.
  final EnsureStarterDecks ensureStarterDecks;

  /// Настройки игрока.
  final WatchSettings watchSettings;

  /// Сохранение настроек.
  final SaveSettings saveSettings;

  /// Уровень сложности бота, выбранный в прошлый раз.
  final LoadBotDifficulty loadBotDifficulty;

  /// Запоминание выбранного уровня сложности бота.
  final SaveBotDifficulty saveBotDifficulty;

  /// Версии приложения, набора карт и сетевого протокола для экрана настроек.
  final LoadAboutInfo loadAboutInfo;

  /// Проверка обновления набора карт.
  final CheckContentUpdate checkContentUpdate;

  /// История партий.
  final WatchMatchHistory watchMatchHistory;

  /// Запись партии в историю.
  final RecordMatch recordMatch;

  /// Подготовка главного меню: набор карт, стартовые колоды, версии.
  late final LoadMenu loadMenu;

  /// Колода бота против игрока.
  late final ChooseOpponentDeck chooseOpponentDeck;

  /// Начало местной партии (hot-seat или против бота).
  late final StartMatch startMatch;

  /// Запись законченной партии в историю.
  late final RecordFinishedMatch recordFinishedMatch;

  /// Загрузка реплея партии из истории.
  late final LoadReplay loadReplay;

  /// Сетевая игра, которую сейчас ведёт телефон: общая для лобби и партии.
  late final ActiveNetworkGame activeNetworkGame;

  /// Контент, набор правил и имя игрока для сетевой игры.
  late final LoadNetworkSetup loadNetworkSetup;

  /// Создание сетевой игры (хост).
  late final HostNetworkGame hostNetworkGame;

  /// Готовность телефона к сетевой игре: Wi-Fi, доступ к локальной сети, переход в настройки.
  late final NetworkReadiness networkReadiness;

  /// Подключение к найденной партии (гость).
  late final JoinNetworkGame joinNetworkGame;

  /// Поиск партий рядом.
  late final DiscoverNetworkGames discoverNetworkGames;

  /// Создание игры через интернет (хост): комната с кодом на сервере, адрес игры `OnlineAddress` с кодом для гостя
  /// берётся из `NetworkGame.address()` и меняется, когда хост создаёт комнату заново (ADR 0026).
  late final HostNetworkGame hostOnlineGame;

  /// Вход в игру через интернет (гость) по коду: `joinOnlineGame.byAddress(OnlineAddress(code), playerName: …)`. Код
  /// из ввода игрока разбирает `RoomCode.tryParse`.
  late final JoinNetworkGame joinOnlineGame;

  /// Звуковые эффекты с громкостью из настроек (ADR 0023).
  late final PlaySound playSound;

  /// Вибрация (ADR 0031).
  late final PlayHaptic playHaptic;

  /// Фоновая музыка с громкостью из настроек (ADR 0023).
  late final BackgroundMusic backgroundMusic;
}
