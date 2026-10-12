import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/core/domain/id_generator.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';

/// Сценарий: сохранить стартовую колоду фракции и сделать её активной.
///
/// Состав колоды описан в [DeckRules.starterDeck].
final class CreateStarterDeck {
  /// Создаёт сценарий.
  const CreateStarterDeck(this._repository, this._rules, this._clock, this._ids);

  final DeckRepository _repository;
  final DeckRulesSource _rules;
  final Clock _clock;
  final IdGenerator _ids;

  /// Сохраняет стартовую колоду фракции [factionId] и возвращает её.
  ///
  /// Бросает [NotADeckFactionException], если из фракции нельзя собрать колоду.
  Future<Deck> call(String factionId) async {
    final rules = await _rules.load();
    final deck = rules.starterDeck(factionId, id: _ids.next(), updatedAt: _clock.now());
    await _repository.save(deck);
    await _repository.setActive(deck);
    return deck;
  }
}
