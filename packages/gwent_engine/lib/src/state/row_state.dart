import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/field_card.dart';
import 'package:gwent_engine/src/state/row_slot.dart';

/// Ряд на стороне игрока: карты в порядке выкладки и слот рога.
final class RowState extends Value {
  const RowState({this.cards = const [], this.slot});

  final List<FieldCard> cards;
  final RowSlot? slot;

  @override
  List<Object?> get props => [cards, slot];
}
