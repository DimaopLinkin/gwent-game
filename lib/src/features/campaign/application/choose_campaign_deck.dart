import 'package:gwent/src/features/collection/domain/collection_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';

/// Сценарий: выбрать колоду, с которой игрок идёт в партии кампании (ADR 0033).
///
/// Выбор запоминается в настройках кампании. Активные колоды фракций свободной игры (`SetActiveDeck`,
/// `GetActiveDeck`, ADR 0008) сценарий не читает и не меняет.
final class ChooseCampaignDeck {
  /// Создаёт сценарий.
  const ChooseCampaignDeck(this._decks, this._rules, this._collection, this._settings);

  final DeckRepository _decks;
  final DeckRulesSource _rules;
  final CollectionRepository _collection;
  final SettingsRepository _settings;

  /// Запоминает колоду [deckId] как колоду кампании.
  ///
  /// Бросает [DeckNotFoundException], если колоды нет, и [InvalidDeckException], если она не годится для кампании:
  /// нарушает правила сборки или в ней есть неоткрытые карты и лидер.
  Future<void> call(String deckId) async {
    final deck = await _decks.findById(deckId) ?? (throw DeckNotFoundException(deckId));
    final issues = (await _rules.load()).check(deck, owned: await _collection.load());
    if (issues.isNotEmpty) throw InvalidDeckException(deckId, issues);
    final settings = await _settings.watch().first;
    if (settings.campaignDeckId == deckId) return;
    await _settings.save(settings.withCampaignDeck(deckId));
  }
}
