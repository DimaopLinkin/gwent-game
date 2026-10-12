import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent_engine/gwent_engine.dart' as engine;

/// Колода приложения в том виде, в каком её принимает движок.
extension EngineDeck on Deck {
  /// Лидер и по элементу на каждую копию карты.
  ///
  /// Карты упорядочены по UUID: одна и та же колода всегда даёт один и тот же список, поэтому партия с тем же сидом
  /// на двух устройствах раздаёт одинаково.
  engine.Deck toEngineDeck() {
    final ids = cards.keys.toList()..sort();
    return engine.Deck(
      leader: engine.LeaderId(leaderId),
      cards: List.unmodifiable([
        for (final id in ids)
          for (var copy = 0; copy < cards[id]!; copy++) engine.CardId(id),
      ]),
    );
  }
}
