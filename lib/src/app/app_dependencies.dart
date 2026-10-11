import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/core/domain/id_generator.dart';
import 'package:gwent/src/features/deck_builder/application/delete_deck.dart';
import 'package:gwent/src/features/deck_builder/application/save_deck.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/application/watch_match_history.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/settings/application/save_settings.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';

/// Сценарии приложения, собранные над интерфейсами.
///
/// Знает только абстракции: реализации выбирает точка сборки (`composition_root.dart`), а тесты подставляют фейки.
/// Экраны получают отсюда сценарии через конструкторы своих держателей состояния (см. `router/app_router.dart`).
final class AppDependencies {
  /// Собирает сценарии.
  AppDependencies({
    required DeckRepository deckRepository,
    required SettingsRepository settingsRepository,
    required MatchHistoryRepository matchHistoryRepository,
    required Clock clock,
    required IdGenerator idGenerator,
  }) : watchDecks = WatchDecks(deckRepository),
       saveDeck = SaveDeck(deckRepository, clock, idGenerator),
       deleteDeck = DeleteDeck(deckRepository),
       watchSettings = WatchSettings(settingsRepository),
       saveSettings = SaveSettings(settingsRepository),
       watchMatchHistory = WatchMatchHistory(matchHistoryRepository),
       recordMatch = RecordMatch(matchHistoryRepository, clock, idGenerator);

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
}
