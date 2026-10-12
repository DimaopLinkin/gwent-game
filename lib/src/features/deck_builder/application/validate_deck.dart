import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';

/// Сценарий: проверить колоду по правилам сборки активного пакета контента.
final class ValidateDeck {
  /// Создаёт сценарий.
  const ValidateDeck(this._rules);

  final DeckRulesSource _rules;

  /// Все проблемы колоды [deck]; пустой список значит, что с ней можно идти в партию.
  Future<List<DeckIssue>> call(Deck deck) async => (await _rules.load()).check(deck);
}
