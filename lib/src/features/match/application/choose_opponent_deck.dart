import 'package:gwent/src/features/deck_builder/application/get_active_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';

/// Сценарий: колода бота против игрока.
///
/// Бот играет следующей по порядку пакета фракцией после фракции игрока (после последней идёт первая), чтобы
/// фракции в партиях против бота менялись, а не повторялись. Колода бота — активная колода той фракции
/// (`GetActiveDeck`): её игрок выбрал или собрал сам, а если подходящей нет, сценарий создаёт стартовую.
final class ChooseOpponentDeck {
  /// Создаёт сценарий.
  const ChooseOpponentDeck(this._rules, this._getActiveDeck);

  final DeckRulesSource _rules;
  final GetActiveDeck _getActiveDeck;

  /// Колода бота против игрока, играющего фракцией [playerFactionId].
  ///
  /// Бросает [NotADeckFactionException], если в пакете нет ни одной фракции с колодой.
  Future<Deck> call(String playerFactionId) async {
    final factions = (await _rules.load()).deckFactions;
    if (factions.isEmpty) throw NotADeckFactionException(playerFactionId);
    final index = factions.indexWhere((faction) => faction.id == playerFactionId);
    return _getActiveDeck(factions[(index + 1) % factions.length].id);
  }
}
