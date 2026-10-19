import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/core/value.dart';

/// Конкретный экземпляр карты в партии.
final class CardInstance extends Value {
  const CardInstance(this.id, this.cardId);

  final CardInstanceId id;
  final CardId cardId;

  @override
  List<Object?> get props => [id, cardId];
}
