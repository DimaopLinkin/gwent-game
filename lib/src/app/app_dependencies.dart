import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/core/domain/id_generator.dart';
import 'package:gwent/src/core/domain/seed_generator.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/deck_builder/application/delete_deck.dart';
import 'package:gwent/src/features/deck_builder/application/save_deck.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/application/watch_match_history.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
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
  AppDependencies({
    required ContentSource contentSource,
    required DeckRepository deckRepository,
    required SettingsRepository settingsRepository,
    required MatchHistoryRepository matchHistoryRepository,
    required Clock clock,
    required IdGenerator idGenerator,
    required SeedGenerator seedGenerator,
    Duration botThinkTime = const Duration(milliseconds: 700),
  }) : loadGameContent = LoadGameContent(contentSource),
       watchDecks = WatchDecks(deckRepository),
       saveDeck = SaveDeck(deckRepository, clock, idGenerator),
       deleteDeck = DeleteDeck(deckRepository),
       watchSettings = WatchSettings(settingsRepository),
       saveSettings = SaveSettings(settingsRepository),
       watchMatchHistory = WatchMatchHistory(matchHistoryRepository),
       recordMatch = RecordMatch(matchHistoryRepository, clock, idGenerator) {
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

  /// Настройки игрока.
  final WatchSettings watchSettings;

  /// Сохранение настроек.
  final SaveSettings saveSettings;

  /// История партий.
  final WatchMatchHistory watchMatchHistory;

  /// Запись партии в историю.
  final RecordMatch recordMatch;

  /// Начало местной партии (hot-seat или против бота).
  late final StartMatch startMatch;

  /// Запись законченной местной партии в историю.
  late final RecordFinishedMatch recordFinishedMatch;
}
