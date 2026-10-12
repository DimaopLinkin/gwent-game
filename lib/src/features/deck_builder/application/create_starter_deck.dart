import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/core/domain/id_generator.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';

/// Шаг сценариев: сохранить стартовую колоду фракции активной.
///
/// Отдельно не вызывается: им пользуются `GetActiveDeck` и `EnsureStarterDecks` внутри [DeckSelectionLock].
/// Состав колоды описан в [DeckRules.starterDeck].
final class CreateStarterDeck {
  /// Создаёт шаг.
  const CreateStarterDeck(this._repository, this._clock, this._ids);

  final DeckRepository _repository;
  final Clock _clock;
  final IdGenerator _ids;

  /// Сохраняет активной стартовую колоду фракции [factionId] по правилам [rules] и возвращает её.
  ///
  /// Бросает [NotADeckFactionException], если из фракции нельзя собрать колоду, и [InvalidDeckException], если
  /// стартовая колода не прошла проверку (параметры колоды разошлись с пакетом); тогда ничего не сохраняется.
  Future<Deck> call(DeckRules rules, String factionId) async {
    final deck = rules.starterDeck(factionId, id: _ids.next(), updatedAt: _clock.now());
    final issues = rules.check(deck);
    if (issues.isNotEmpty) throw InvalidDeckException(deck.id, issues);
    await _repository.save(deck, activate: true);
    return deck;
  }
}
