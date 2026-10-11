import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/choice.dart';
import 'package:gwent_engine/src/state/entry_source.dart';
import 'package:gwent_engine/src/state/match_outcome.dart';
import 'package:gwent_engine/src/state/round_result.dart';
import 'package:gwent_engine/src/state/row_slot.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Событие партии: что произошло в результате намерения.
///
/// Движок возвращает полные события; перед отправкой игроку их пропускают через `eventsFor`,
/// который прячет скрытую информацию (раздел 4 сетевой спецификации).
sealed class GameEvent extends Value {
  const GameEvent();
}

/// Решено, кто ходит первым в партии.
final class FirstPlayerChosen extends GameEvent {
  const FirstPlayerChosen(this.seat, {required this.byChoice});

  final Seat seat;

  /// `true`, если решил игрок Скоя'таэлей, `false` при броске монетки.
  final bool byChoice;

  @override
  List<Object?> get props => [seat, byChoice];
}

/// Колода игрока перемешана.
final class DeckShuffled extends GameEvent {
  const DeckShuffled(this.seat);

  final Seat seat;

  @override
  List<Object?> get props => [seat];
}

/// Игрок взял карты в руку. Сопернику уходит [CardsDrawnHidden].
final class CardsDrawn extends GameEvent {
  const CardsDrawn(this.seat, this.cards);

  final Seat seat;
  final List<CardInstance> cards;

  @override
  List<Object?> get props => [seat, cards];
}

/// Соперник взял [count] карт; какие, не видно.
final class CardsDrawnHidden extends GameEvent {
  const CardsDrawnHidden(this.seat, this.count);

  final Seat seat;
  final int count;

  @override
  List<Object?> get props => [seat, count];
}

/// Игрок заменил карту при пересдаче. Сопернику не отправляется.
final class CardRedrawn extends GameEvent {
  const CardRedrawn(this.seat, {required this.returned, required this.drawn});

  final Seat seat;
  final CardInstance returned;
  final CardInstance drawn;

  @override
  List<Object?> get props => [seat, returned, drawn];
}

/// Игрок закончил пересдачу.
final class RedrawFinished extends GameEvent {
  const RedrawFinished(this.seat);

  final Seat seat;

  @override
  List<Object?> get props => [seat];
}

/// Начался раунд.
final class RoundStarted extends GameEvent {
  const RoundStarted(this.round, this.starter);

  final int round;
  final Seat starter;

  @override
  List<Object?> get props => [round, starter];
}

/// Начался ход игрока.
final class TurnStarted extends GameEvent {
  const TurnStarted(this.seat);

  final Seat seat;

  @override
  List<Object?> get props => [seat];
}

/// Игрок сыграл карту из руки.
final class CardPlayed extends GameEvent {
  const CardPlayed(this.seat, this.card);

  final Seat seat;
  final CardInstance card;

  @override
  List<Object?> get props => [seat, card];
}

/// Отряд лёг в ряд на стороне [side].
final class UnitPlaced extends GameEvent {
  const UnitPlaced(this.side, this.row, this.card, this.source);

  final Seat side;
  final Row row;
  final CardInstance card;
  final EntrySource source;

  @override
  List<Object?> get props => [side, row, card, source];
}

/// Созданная карта появилась на поле (Приманка).
final class CreatedCardPlaced extends GameEvent {
  const CreatedCardPlaced(this.side, this.row, this.card);

  final Seat side;
  final Row row;
  final CardInstance card;

  @override
  List<Object?> get props => [side, row, card];
}

/// Берсерк превратился в созданную карту.
final class BerserkTransformed extends GameEvent {
  const BerserkTransformed(this.side, this.row, {required this.berserk, required this.into});

  final Seat side;
  final Row row;
  final CardInstance berserk;
  final CardInstance into;

  @override
  List<Object?> get props => [side, row, berserk, into];
}

/// В слот рога ряда положена карта или рог лидера.
final class SlotFilled extends GameEvent {
  const SlotFilled(this.side, this.row, this.slot);

  final Seat side;
  final Row row;
  final RowSlot slot;

  @override
  List<Object?> get props => [side, row, slot];
}

/// Карта погоды легла в зону погоды.
final class WeatherPlayed extends GameEvent {
  const WeatherPlayed(this.owner, this.card);

  final Seat owner;
  final CardInstance card;

  @override
  List<Object?> get props => [owner, card];
}

/// Вся погода снята.
final class WeatherCleared extends GameEvent {
  const WeatherCleared();

  @override
  List<Object?> get props => const [];
}

/// Чучело встало на место отряда, отряд вернулся в руку.
final class UnitDecoyed extends GameEvent {
  const UnitDecoyed(this.seat, this.row, {required this.decoy, required this.returned});

  final Seat seat;
  final Row row;
  final CardInstance decoy;
  final CardInstance returned;

  @override
  List<Object?> get props => [seat, row, decoy, returned];
}

/// Отряды уничтожены Казнью.
final class UnitsDestroyed extends GameEvent {
  const UnitsDestroyed(this.units);

  final List<DestroyedUnit> units;

  @override
  List<Object?> get props => [units];
}

/// Уничтоженный отряд.
final class DestroyedUnit extends Value {
  const DestroyedUnit(this.side, this.row, this.card);

  final Seat side;
  final Row row;
  final CardInstance card;

  @override
  List<Object?> get props => [side, row, card];
}

/// Карта ушла в отбой хозяина.
final class CardDiscarded extends GameEvent {
  const CardDiscarded(this.owner, this.card);

  final Seat owner;
  final CardInstance card;

  @override
  List<Object?> get props => [owner, card];
}

/// Созданная карта вышла из игры (раздел 1.2).
final class CardLeftGame extends GameEvent {
  const CardLeftGame(this.card);

  final CardInstance card;

  @override
  List<Object?> get props => [card];
}

/// Карта из отбоя игрока [from] взята в руку [seat].
final class CardTakenFromDiscard extends GameEvent {
  const CardTakenFromDiscard(this.seat, this.from, this.card);

  final Seat seat;
  final Seat from;
  final CardInstance card;

  @override
  List<Object?> get props => [seat, from, card];
}

/// Отбой игрока замешан в его колоду.
final class DiscardShuffledIntoDeck extends GameEvent {
  const DiscardShuffledIntoDeck(this.seat);

  final Seat seat;

  @override
  List<Object?> get props => [seat];
}

/// Игрок применил способность лидера.
final class LeaderUsed extends GameEvent {
  const LeaderUsed(this.seat, this.leader);

  final Seat seat;
  final LeaderId leader;

  @override
  List<Object?> get props => [seat, leader];
}

/// Игроку [viewer] показаны карты руки соперника. Отправляется только ему.
final class HandRevealed extends GameEvent {
  const HandRevealed(this.viewer, this.cards);

  final Seat viewer;
  final List<CardInstance> cards;

  @override
  List<Object?> get props => [viewer, cards];
}

/// Игрок спасовал.
final class Passed extends GameEvent {
  const Passed(this.seat, {required this.auto});

  final Seat seat;

  /// Автопас: у игрока не было других допустимых действий.
  final bool auto;

  @override
  List<Object?> get props => [seat, auto];
}

/// Партия ждёт выбора игрока. Соперник видит только вид выбора, без вариантов.
final class ChoiceRequested extends GameEvent {
  const ChoiceRequested(this.seat, this.kind, this.options);

  final Seat seat;
  final ChoiceKind kind;
  final List<ChoiceOption> options;

  @override
  List<Object?> get props => [seat, kind, options];
}

/// Перк Чудовищ оставил карту на поле.
final class UnitKept extends GameEvent {
  const UnitKept(this.side, this.row, this.card);

  final Seat side;
  final Row row;
  final CardInstance card;

  @override
  List<Object?> get props => [side, row, card];
}

/// Раунд закончен.
final class RoundEnded extends GameEvent {
  const RoundEnded(this.result);

  final RoundResult result;

  @override
  List<Object?> get props => [result];
}

/// Партия закончена.
final class MatchEnded extends GameEvent {
  const MatchEnded(this.outcome);

  final MatchOutcome outcome;

  @override
  List<Object?> get props => [outcome];
}

/// Отряд передвинут в другой ряд своей стороны (Надежда Aen Seidhe). Это не выход на поле.
final class UnitMoved extends GameEvent {
  const UnitMoved(this.side, this.card, {required this.from, required this.to});

  final Seat side;
  final CardInstance card;
  final Row from;
  final Row to;

  @override
  List<Object?> get props => [side, card, from, to];
}
