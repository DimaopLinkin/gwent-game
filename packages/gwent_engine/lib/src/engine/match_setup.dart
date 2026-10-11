import 'package:gwent_engine/src/cards/deck.dart';
import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/random/rng.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Всё, что нужно для начала партии: колоды игроков и генератор случайных чисел с сидом.
final class MatchSetup extends Value {
  const MatchSetup({required this.decks, required this.rng});

  /// Колода каждого игрока.
  final Map<Seat, Deck> decks;

  /// Генератор партии, обычно `SeededRng(seed)`.
  final Rng rng;

  @override
  List<Object?> get props => [decks, rng];
}
