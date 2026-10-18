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
import 'package:gwent/src/features/match/application/choose_opponent_deck.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/application/watch_match_history.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/menu/application/load_menu.dart';
import 'package:gwent/src/features/settings/application/check_content_update.dart';
import 'package:gwent/src/features/settings/application/load_about_info.dart';
import 'package:gwent/src/features/settings/application/save_settings.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';
import 'package:gwent_content/gwent_content.dart';

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
       loadAboutInfo = LoadAboutInfo(appInfo, loadGameContent),
       checkContentUpdate = CheckContentUpdate(loadGameContent, clock),
       watchMatchHistory = WatchMatchHistory(matchHistoryRepository),
       recordMatch = RecordMatch(matchHistoryRepository, clock, idGenerator) {
    chooseOpponentDeck = ChooseOpponentDeck(deckRules, getActiveDeck);
    loadMenu = LoadMenu(appInfo, loadGameContent, ensureStarterDecks);
    startMatch = StartMatch(loadGameContent, deckRepository, seedGenerator, botThinkTime: botThinkTime);
    recordFinishedMatch = RecordFinishedMatch(recordMatch);
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

  /// Запись законченной местной партии в историю.
  late final RecordFinishedMatch recordFinishedMatch;
}
