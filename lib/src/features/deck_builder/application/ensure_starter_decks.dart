import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';

/// Сценарий: дать каждой фракции хотя бы одну колоду, чтобы с первого запуска было с чем идти в партию.
final class EnsureStarterDecks {
  /// Создаёт сценарий.
  const EnsureStarterDecks(this._repository, this._rules, this._createStarterDeck);

  final DeckRepository _repository;
  final DeckRulesSource _rules;
  final CreateStarterDeck _createStarterDeck;

  /// Сохраняет стартовую колоду каждой фракции, у которой колод нет, и возвращает созданные колоды.
  Future<List<Deck>> call() async {
    final rules = await _rules.load();
    final created = <Deck>[];
    for (final faction in rules.deckFactions) {
      if ((await _repository.findByFaction(faction.id)).isEmpty) {
        created.add(await _createStarterDeck(faction.id));
      }
    }
    return List.unmodifiable(created);
  }
}
