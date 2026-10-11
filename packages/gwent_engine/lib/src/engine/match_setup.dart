import 'package:gwent_engine/src/cards/deck.dart';
import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/random/rng.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Всё, что нужно для начала партии: колоды игроков и генератор случайных чисел с сидом.
final class MatchSetup extends Value {
  const MatchSetup({required this.one, required this.two, required this.rng});

  /// Колода игрока 1.
  final Deck one;

  /// Колода игрока 2.
  final Deck two;

  /// Генератор партии, обычно `SeededRng(seed)`.
  final Rng rng;

  /// Колода игрока [seat].
  Deck deck(Seat seat) => switch (seat) {
    Seat.one => one,
    Seat.two => two,
  };

  @override
  List<Object?> get props => [one, two, rng];
}
