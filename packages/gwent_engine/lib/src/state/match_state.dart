import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/random/rng.dart';
import 'package:gwent_engine/src/state/choice.dart';
import 'package:gwent_engine/src/state/effect.dart';
import 'package:gwent_engine/src/state/match_outcome.dart';
import 'package:gwent_engine/src/state/match_phase.dart';
import 'package:gwent_engine/src/state/player_state.dart';
import 'package:gwent_engine/src/state/round_result.dart';
import 'package:gwent_engine/src/state/seat.dart';
import 'package:gwent_engine/src/state/weather_card.dart';
import 'package:meta/meta.dart';

/// Полное состояние партии. Его видит только авторитетная сторона (хост или сервер);
/// игрокам отдаётся проекция `PlayerView`.
final class MatchState extends Value {
  const MatchState({
    required this.phase,
    required this.round,
    required this.players,
    required this.rng,
    required this.nextInstanceId,
    this.roundStarter,
    this.turn,
    this.weather = const [],
    this.choice,
    this.effects = const [],
    this.history = const [],
    this.outcome,
  });

  final MatchPhase phase;

  /// Номер текущего раунда, с 1; до начала первого раунда 0.
  final int round;
  final Map<Seat, PlayerState> players;

  /// Кто начал (или начнёт) текущий раунд; `null`, пока не решено, кто ходит первым.
  final Seat? roundStarter;

  /// Чей ход; `null`, пока ходов нет (подготовка, выбор вне хода, конец партии).
  final Seat? turn;

  /// Общая зона погоды в порядке выкладки.
  final List<WeatherCard> weather;

  /// Выбор, которого ждёт партия.
  final PendingChoice? choice;

  /// Невыполненные шаги разрешения; последний элемент выполняется первым.
  @internal
  final List<Effect> effects;

  /// Итоги сыгранных раундов.
  final List<RoundResult> history;
  final MatchOutcome? outcome;
  final Rng rng;

  /// Номер для следующего созданного экземпляра карты.
  final int nextInstanceId;

  PlayerState player(Seat seat) => players[seat]!;

  @override
  List<Object?> get props => [
    phase,
    round,
    players,
    roundStarter,
    turn,
    weather,
    choice,
    effects,
    history,
    outcome,
    rng,
    nextInstanceId,
  ];
}
