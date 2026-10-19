import 'package:gwent/src/core/domain/seed_generator.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';
import 'package:gwent/src/features/match/domain/bot_deck_builder.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;
import 'package:gwent_engine/gwent_engine.dart' show SeededRng;

/// Сценарий: колода бота против игрока (ADR 0021).
///
/// Фракция бота выбирается случайно среди всех фракций с колодой, в том числе совпадающей с фракцией игрока.
/// Колоду бот собирает сам под уровень сложности ([BotDeckBuilder]) с долей случайности: колода одного уровня
/// каждый раз другая. Случайность идёт от [SeedGenerator], поэтому с фиксированным сидом выбор повторяется.
/// Колода в хранилище не попадает: она живёт только в запросе на партию.
final class ChooseOpponentDeck {
  /// Создаёт сценарий.
  const ChooseOpponentDeck(this._rules, this._seeds);

  final DeckRulesSource _rules;
  final SeedGenerator _seeds;

  /// Колода бота уровня [difficulty].
  ///
  /// Бросает [NotADeckFactionException], если в пакете нет ни одной фракции с колодой.
  Future<Deck> call(BotDifficulty difficulty) async {
    final rules = await _rules.load();
    final factions = rules.deckFactions;
    if (factions.isEmpty) throw const NotADeckFactionException('');
    final (index, rng) = SeededRng(_seeds.next()).nextInt(factions.length);
    return BotDeckBuilder(rules).build(factions[index].id, difficulty, rng);
  }
}
