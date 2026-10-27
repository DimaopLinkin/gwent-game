import 'package:gwent/src/features/campaign/domain/campaign_deck.dart';
import 'package:gwent/src/features/collection/domain/collection_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';

/// Сценарий: колоды игрока с отметкой, годны ли они для кампании (ADR 0033).
///
/// Годность вычисляется при каждом вызове по открытым картам и нигде не хранится. Колоды свободной игры не
/// меняются и не удаляются: негодные просто помечены.
final class ListCampaignDecks {
  /// Создаёт сценарий.
  const ListCampaignDecks(this._decks, this._rules, this._collection);

  final DeckRepository _decks;
  final DeckRulesSource _rules;
  final CollectionRepository _collection;

  /// Все колоды, сначала недавно изменённые, с проблемами для кампании.
  Future<List<CampaignDeck>> call() async {
    final rules = await _rules.load();
    final owned = await _collection.load();
    final decks = await _decks.watchAll().first;
    return [for (final deck in decks) CampaignDeck(deck, rules.check(deck, owned: owned))];
  }
}
