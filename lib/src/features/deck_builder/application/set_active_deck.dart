import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';

/// Сценарий: выбрать колоду, с которой игрок идёт в партию за её фракцию.
final class SetActiveDeck {
  /// Создаёт сценарий.
  const SetActiveDeck(this._repository, this._rules);

  final DeckRepository _repository;
  final DeckRulesSource _rules;

  /// Делает колоду [deckId] активной колодой её фракции.
  ///
  /// Бросает [DeckNotFoundException], если колоды нет, и [InvalidDeckException], если она нарушает правила сборки:
  /// с такой колодой в партию не идут (раздел 2.3 `docs/hand/main.md`).
  Future<void> call(String deckId) async {
    final deck = await _repository.findById(deckId) ?? (throw DeckNotFoundException(deckId));
    final issues = (await _rules.load()).check(deck);
    if (issues.isNotEmpty) throw InvalidDeckException(deckId, issues);
    await _repository.setActive(deck);
  }
}
