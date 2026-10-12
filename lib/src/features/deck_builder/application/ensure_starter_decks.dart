import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';

/// Сценарий: дать каждой фракции хотя бы одну колоду, чтобы было с чем идти в партию.
///
/// Фракция, у которой игрок удалил все колоды, тоже получает стартовую колоду заново: без колоды за фракцию
/// не сыграть, а редактор колод может не успеть появиться.
final class EnsureStarterDecks {
  /// Создаёт сценарий; [lock] общий с `GetActiveDeck`.
  const EnsureStarterDecks(this._repository, this._rules, this._createStarterDeck, this._lock);

  final DeckRepository _repository;
  final DeckRulesSource _rules;
  final CreateStarterDeck _createStarterDeck;
  final DeckSelectionLock _lock;

  /// Сохраняет активной стартовую колоду каждой фракции, у которой колод нет, и возвращает созданные колоды.
  Future<List<Deck>> call() => _lock.run(() async {
    final rules = await _rules.load();
    final created = <Deck>[];
    for (final faction in rules.deckFactions) {
      if ((await _repository.findByFaction(faction.id)).isEmpty) {
        created.add(await _createStarterDeck(rules, faction.id));
      }
    }
    return List.unmodifiable(created);
  });
}
