import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/core/value.dart';

/// Колода, с которой игрок идёт в партию: лидер и карты (по одному элементу на копию).
final class Deck extends Value {
  const Deck({required this.leader, required this.cards});

  final LeaderId leader;
  final List<CardId> cards;

  @override
  List<Object?> get props => [leader, cards];
}
