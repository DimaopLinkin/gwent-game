import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/card_instance.dart';

/// Карта в ряду на поле: отряд или Чучело.
final class FieldCard extends Value {
  const FieldCard(this.card, {this.beneath, this.kept = false});

  /// Видимая карта. Для всех правил на поле лежит именно она.
  final CardInstance card;

  /// Берсерк, превращённый в эту созданную карту: лежит «под» ней и для правил не виден (раздел 9.4).
  final CardInstance? beneath;

  /// Карту оставил на поле перк Чудовищ; пометка снимается в начале следующего раунда.
  final bool kept;

  FieldCard copyWith({bool? kept}) => FieldCard(card, beneath: beneath, kept: kept ?? this.kept);

  @override
  List<Object?> get props => [card, beneath, kept];
}
