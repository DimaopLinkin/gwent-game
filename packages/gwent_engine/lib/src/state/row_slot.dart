import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/card_instance.dart';

/// Содержимое слота рога у ряда: Командирский рог, Мардрём или рог лидера (раздел 9.3).
sealed class RowSlot extends Value {
  const RowSlot();
}

/// Специальная карта в слоте: Командирский рог или Мардрём.
final class CardSlot extends RowSlot {
  const CardSlot(this.card);

  final CardInstance card;

  @override
  List<Object?> get props => [card];
}

/// Рог лидера: эффект, а не карта; в конце раунда исчезает.
final class LeaderHornSlot extends RowSlot {
  const LeaderHornSlot();

  @override
  List<Object?> get props => const [];
}
