import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart' as app;
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart' as net;

/// Партия, которую два бота доиграли до конца настоящим движком.
final class BotMatch {
  BotMatch({required this.record, required this.finalView, required this.specialsPlayed});

  /// Журнал принятых ходов: по нему движок заново проигрывает партию.
  final net.MatchRecord record;

  /// Итоговая проекция первого места.
  final PlayerView finalView;

  /// Сколько особых карт сыграло каждое место (считано по событиям `CardPlayed` при игре).
  final Map<Seat, int> specialsPlayed;
}

/// Играет партию колод [one] и [two] двумя жадными ботами уровня [difficulty] с сидом [seed].
BotMatch playBotMatch(
  GameContent content,
  app.Deck one,
  app.Deck two, {
  int seed = 1,
  BotDifficulty difficulty = BotDifficulty.hard,
}) {
  final engine = GwentEngine(content.catalog, rules: content.rules);
  final setup = MatchSetup(one: one.toEngineDeck(), two: two.toEngineDeck(), rng: SeededRng(seed));
  var state = switch (engine.start(setup)) {
    Accepted(:final state) => state,
    Rejected(:final reject) => throw StateError('Партия не начинается: $reject'),
  };
  final manifest = content.pack.manifest;
  var record = net.MatchRecord(
    matchId: 'bot-$seed',
    ruleset: net.Ruleset(id: manifest.packId, hash: manifest.contentHash, engineVersion: engineVersion),
    seed: seed,
    one: setup.one,
    two: setup.two,
  );
  final bots = {
    for (final seat in Seat.values)
      seat: GreedyBot.forDifficulty(engine, content.catalog, difficulty, seed: seed + seat.index),
  };
  final specials = {for (final seat in Seat.values) seat: 0};
  for (var step = 0; step < 5000 && state.outcome == null; step++) {
    var moved = false;
    for (final seat in Seat.values) {
      final intent = bots[seat]!.decide(state, seat);
      if (intent == null) continue;
      switch (engine.apply(state, seat, intent)) {
        case Accepted(state: final next, :final events):
          state = next;
          record = record.adding(net.RecordedMove(seat, intent));
          for (final event in events) {
            if (event is CardPlayed && content.catalog.card(event.card.cardId) is SpecialCardDefinition) {
              specials[event.seat] = specials[event.seat]! + 1;
            }
          }
          moved = true;
        case Rejected(:final reject):
          throw StateError('Бот $seat сыграл $intent, а движок отклонил: $reject');
      }
      if (moved) break;
    }
    if (!moved) throw StateError('Ни один бот не ходит, а партия не закончена');
  }
  return BotMatch(record: record, finalView: engine.project(state, Seat.one), specialsPlayed: specials);
}
