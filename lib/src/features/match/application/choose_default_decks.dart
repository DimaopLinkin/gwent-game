import 'package:gwent/src/features/deck_builder/application/get_active_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';
import 'package:meta/meta.dart';

/// Колоды двух мест, с которыми партия начинается одним нажатием.
@immutable
final class DefaultDecks {
  /// Создаёт пару колод.
  const DefaultDecks({required this.deckOne, required this.deckTwo});

  /// Идентификатор колоды первого места.
  final String deckOne;

  /// Идентификатор колоды второго места.
  final String deckTwo;
}

/// Сценарий: колоды по умолчанию для местной партии.
///
/// Колоду первого места даёт первая фракция пакета, колоду второго — вторая, чтобы играли разные фракции. В обоих
/// случаях это активная колода фракции (`GetActiveDeck`): её игрок выбрал или собрал сам, а если подходящей нет,
/// сценарий создаёт стартовую. Выбор фракции и колоды руками появится вместе с экраном выбора фракции.
final class ChooseDefaultDecks {
  /// Создаёт сценарий.
  const ChooseDefaultDecks(this._rules, this._getActiveDeck);

  final DeckRulesSource _rules;
  final GetActiveDeck _getActiveDeck;

  /// Колоды по умолчанию; `null`, если в пакете нет ни одной фракции с колодой.
  Future<DefaultDecks?> call() async {
    final factions = (await _rules.load()).deckFactions;
    if (factions.isEmpty) return null;
    final one = await _getActiveDeck(factions.first.id);
    final two = factions.length > 1 ? await _getActiveDeck(factions[1].id) : one;
    return DefaultDecks(deckOne: one.id, deckTwo: two.id);
  }
}
