import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/core/value.dart';

/// Нарушение правил сборки колоды (разделы 2.1 и 2.2).
sealed class DeckViolation extends Value {
  const DeckViolation();
}

/// Лидера нет в справочнике.
final class UnknownLeader extends DeckViolation {
  const UnknownLeader(this.leader);

  final LeaderId leader;

  @override
  List<Object?> get props => [leader];
}

/// Лидер принадлежит фракции, которая не может быть колодой.
final class LeaderNotDeckFaction extends DeckViolation {
  const LeaderNotDeckFaction(this.leader);

  final LeaderId leader;

  @override
  List<Object?> get props => [leader];
}

/// Карты нет в справочнике.
final class UnknownCard extends DeckViolation {
  const UnknownCard(this.card);

  final CardId card;

  @override
  List<Object?> get props => [card];
}

/// Карта чужой фракции: в колоду идут только карты фракции лидера и нейтральные.
final class WrongFaction extends DeckViolation {
  const WrongFaction(this.card);

  final CardId card;

  @override
  List<Object?> get props => [card];
}

/// Созданную карту (`count = 0`) нельзя положить в колоду.
final class CreatedCardInDeck extends DeckViolation {
  const CreatedCardInDeck(this.card);

  final CardId card;

  @override
  List<Object?> get props => [card];
}

/// Копий карты больше, чем существует в игре.
final class TooManyCopies extends DeckViolation {
  const TooManyCopies(this.card, {required this.count, required this.max});

  final CardId card;
  final int count;
  final int max;

  @override
  List<Object?> get props => [card, count, max];
}

/// Карт отрядов меньше минимума.
final class TooFewUnitCards extends DeckViolation {
  const TooFewUnitCards({required this.count, required this.min});

  final int count;
  final int min;

  @override
  List<Object?> get props => [count, min];
}

/// Специальных карт больше максимума.
final class TooManySpecialCards extends DeckViolation {
  const TooManySpecialCards({required this.count, required this.max});

  final int count;
  final int max;

  @override
  List<Object?> get props => [count, max];
}
