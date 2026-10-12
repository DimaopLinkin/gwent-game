import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';

/// Сценарий: колода, с которой игрок идёт в партию за фракцию.
///
/// Перевести колоду в вид, понятный движку, можно расширением `toEngineDeck` (`domain/engine_deck.dart`).
final class GetActiveDeck {
  /// Создаёт сценарий.
  const GetActiveDeck(this._repository, this._rules, this._createStarterDeck);

  final DeckRepository _repository;
  final DeckRulesSource _rules;
  final CreateStarterDeck _createStarterDeck;

  /// Годная колода фракции [factionId]; результат всегда проходит проверку правил сборки.
  ///
  /// Это активная колода фракции, если она годится. Иначе активной становится самая недавно изменённая годная
  /// колода фракции, а если таких нет, то новая стартовая колода. Так игрок не остаётся без колоды, даже если
  /// новый пакет контента сделал его колоды негодными: сами они не удаляются и ждут правки.
  ///
  /// Бросает [NotADeckFactionException], если из фракции нельзя собрать колоду.
  Future<Deck> call(String factionId) async {
    final rules = await _rules.load();
    if (!rules.isDeckFaction(factionId)) throw NotADeckFactionException(factionId);

    final activeId = await _repository.findActiveDeckId(factionId);
    final active = activeId == null ? null : await _repository.findById(activeId);
    if (active != null && rules.check(active).isEmpty) return active;

    for (final deck in await _repository.findByFaction(factionId)) {
      if (deck.id != activeId && rules.check(deck).isEmpty) {
        await _repository.setActive(deck);
        return deck;
      }
    }
    return _createStarterDeck(factionId);
  }
}
