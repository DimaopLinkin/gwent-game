import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Что выбирает игрок, когда эффекту нужно его решение.
enum ChoiceKind {
  /// Скоя'таэли решают, кто ходит первым.
  firstPlayer,

  /// Медик выбирает отряд из своего отбоя.
  medicTarget,

  /// Ряд для проворной карты, которая выходит на поле не из руки.
  unitRow,

  /// Лидер берёт обычный отряд из отбоя соперника.
  opponentDiscardCard,

  /// Лидер возвращает обычный отряд из своего отбоя.
  ownDiscardCard,

  /// Лидер сбрасывает карту из руки.
  handCardToDiscard,

  /// Лидер берёт карту из колоды.
  deckCard,

  /// Лидер выбирает в колоде карту погоды и сразу играет её.
  deckWeather,
}

/// Вариант выбора.
sealed class ChoiceOption extends Value {
  const ChoiceOption();
}

/// Выбор карты.
///
/// Вариант несёт и номер экземпляра, и определение карты: карты из колоды выбирающий не видит в проекции,
/// а отрисовать вариант должен по одному выбору.
final class CardOption extends ChoiceOption {
  const CardOption(this.card);

  final CardInstance card;

  @override
  List<Object?> get props => [card];
}

/// Выбор ряда.
final class RowOption extends ChoiceOption {
  const RowOption(this.row);

  final Row row;

  @override
  List<Object?> get props => [row];
}

/// Выбор игрока.
final class SeatOption extends ChoiceOption {
  const SeatOption(this.seat);

  final Seat seat;

  @override
  List<Object?> get props => [seat];
}

/// Выбор, которого ждёт партия: пока он не сделан, другие намерения отклоняются.
final class PendingChoice extends Value {
  const PendingChoice({required this.seat, required this.kind, required this.options, this.subject});

  /// Кто выбирает.
  final Seat seat;
  final ChoiceKind kind;
  final List<ChoiceOption> options;

  /// Карта, ради которой выбор: для [ChoiceKind.unitRow] — карта, которая выходит на поле.
  final CardInstance? subject;

  @override
  List<Object?> get props => [seat, kind, options, subject];
}
