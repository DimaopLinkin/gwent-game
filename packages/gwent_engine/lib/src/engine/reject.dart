import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/rules/deck_violation.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Почему намерение отклонено. Для клиента это рассинхрон интерфейса, а не ошибка протокола.
enum RejectReason {
  /// Колода не проходит правила сборки; подробности в [Reject.deckViolations].
  invalidDeck,

  /// Партия уже окончена.
  matchFinished,

  /// Намерение не подходит к этапу партии.
  wrongPhase,

  /// Сейчас ход соперника.
  notYourTurn,

  /// Партия ждёт выбора игрока.
  choicePending,

  /// Партия ждёт выбора другого игрока.
  notYourChoice,

  /// Такого варианта в выборе нет.
  invalidOption,

  /// Игрок уже спасовал в этом раунде.
  alreadyPassed,

  /// Пересдача у игрока уже закончена.
  redrawFinished,

  /// Карты нет в руке.
  cardNotInHand,

  /// Для карты нужно указать ряд.
  rowRequired,

  /// Карту нельзя положить в этот ряд.
  invalidRow,

  /// Для карты нужно указать цель.
  targetRequired,

  /// Цель не подходит.
  invalidTarget,

  /// Карте нужна цель, а подходящей нет.
  noValidTarget,

  /// Способность лидера пассивная, отключена или уже применена.
  leaderUnavailable,
}

/// Отказ движка.
final class Reject extends Value {
  const Reject(this.reason, {this.seat, this.deckViolations = const []});

  final RejectReason reason;

  /// Чья колода не прошла проверку (для [RejectReason.invalidDeck]).
  final Seat? seat;
  final List<DeckViolation> deckViolations;

  @override
  List<Object?> get props => [reason, seat, deckViolations];
}
