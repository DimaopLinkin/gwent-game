import 'package:gwent_engine/src/cards/faction.dart';
import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/choice.dart';
import 'package:gwent_engine/src/state/match_outcome.dart';
import 'package:gwent_engine/src/state/match_phase.dart';
import 'package:gwent_engine/src/state/round_result.dart';
import 'package:gwent_engine/src/state/row_slot.dart';
import 'package:gwent_engine/src/state/seat.dart';
import 'package:gwent_engine/src/state/weather_card.dart';

/// Что видит игрок [viewer]: своя рука открыта, чужая рука и обе колоды видны только как количество.
final class PlayerView extends Value {
  const PlayerView({
    required this.viewer,
    required this.phase,
    required this.round,
    required this.me,
    required this.opponent,
    required this.weather,
    required this.history,
    this.roundStarter,
    this.turn,
    this.choice,
    this.opponentChoosing,
    this.outcome,
  });

  final Seat viewer;
  final MatchPhase phase;
  final int round;
  final Seat? roundStarter;
  final Seat? turn;
  final SideView me;
  final SideView opponent;

  /// Карты в общей зоне погоды.
  final List<WeatherCard> weather;

  /// Выбор, которого партия ждёт от этого игрока.
  final PendingChoice? choice;

  /// Вид выбора, которого партия ждёт от соперника, без вариантов.
  final ChoiceKind? opponentChoosing;
  final List<RoundResult> history;
  final MatchOutcome? outcome;

  @override
  List<Object?> get props => [
    viewer,
    phase,
    round,
    roundStarter,
    turn,
    me,
    opponent,
    weather,
    choice,
    opponentChoosing,
    history,
    outcome,
  ];
}

/// Сторона игрока в проекции.
final class SideView extends Value {
  const SideView({
    required this.seat,
    required this.leader,
    required this.faction,
    required this.leaderAvailable,
    required this.leaderUsed,
    required this.leaderDisabled,
    required this.crystals,
    required this.passed,
    required this.handCount,
    required this.deckCount,
    required this.discard,
    required this.rows,
    required this.score,
    required this.redrawDone,
    this.hand,
    this.redrawsLeft,
    this.playable = const {},
  });

  final Seat seat;
  final LeaderId leader;
  final Faction faction;

  /// Активную способность лидера можно применить (если сейчас ход этого игрока).
  final bool leaderAvailable;
  final bool leaderUsed;
  final bool leaderDisabled;
  final int crystals;
  final bool passed;

  /// Рука: только у своей стороны, у соперника `null`.
  final List<CardInstance>? hand;
  final int handCount;
  final int deckCount;
  final List<CardInstance> discard;
  final Map<Row, RowView> rows;

  /// Очки стороны: сумма силы трёх рядов.
  final int score;

  /// Сколько замен осталось при пересдаче: только у своей стороны.
  final int? redrawsLeft;
  final bool redrawDone;

  /// Карты руки, которые можно сыграть сейчас: только у своей стороны и только в свой ход.
  final Set<CardInstanceId> playable;

  @override
  List<Object?> get props => [
    seat,
    leader,
    faction,
    leaderAvailable,
    leaderUsed,
    leaderDisabled,
    crystals,
    passed,
    hand,
    handCount,
    deckCount,
    discard,
    rows,
    score,
    redrawsLeft,
    redrawDone,
    playable,
  ];
}

/// Ряд в проекции.
final class RowView extends Value {
  const RowView({required this.cards, required this.slot, required this.weather, required this.strength});

  final List<FieldCardView> cards;
  final RowSlot? slot;

  /// На ряд действует погода.
  final bool weather;

  /// Сила ряда.
  final int strength;

  @override
  List<Object?> get props => [cards, slot, weather, strength];
}

/// Карта на поле с текущей силой.
final class FieldCardView extends Value {
  const FieldCardView({required this.card, required this.strength, required this.kept});

  final CardInstance card;
  final int strength;

  /// Карту оставил на поле перк Чудовищ.
  final bool kept;

  @override
  List<Object?> get props => [card, strength, kept];
}
