import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Карта в общей зоне погоды и игрок, который её сыграл (её хозяин, раздел 1.1).
final class WeatherCard extends Value {
  const WeatherCard(this.card, this.owner);

  final CardInstance card;
  final Seat owner;

  @override
  List<Object?> get props => [card, owner];
}
