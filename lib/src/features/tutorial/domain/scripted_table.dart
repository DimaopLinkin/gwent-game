import 'package:gwent/src/features/match/domain/local_match_table.dart';
import 'package:gwent/src/features/match/domain/match_pause.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match/domain/seat_agent.dart';
import 'package:gwent/src/features/tutorial/domain/scenario_director.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Стол сценарной партии: местный стол, который пускает только ходы игрока, заданные сценарием.
///
/// Остальное (проекции, события, пауза, закрытие) идёт через настоящий [LocalMatchTable], поэтому экран партии,
/// анимации и движок работают как в обычной партии против бота (ADR 0006, ADR 0034).
final class ScriptedTable implements PausableTable {
  /// Создаёт стол над [inner]; [director] решает, какие ходы игрока допустимы.
  ScriptedTable(this._inner, this._director);

  final LocalMatchTable _inner;
  final ScenarioDirector _director;

  @override
  Set<Seat> get localSeats => _inner.localSeats;

  @override
  Stream<TableUpdate> get updates => _inner.updates;

  @override
  void submit(Seat seat, Intent intent) {
    if (!_director.allows(_inner.state, seat, intent)) return;
    _inner.submit(seat, intent);
  }

  @override
  void setPaused({required bool paused}) => _inner.setPaused(paused: paused);

  @override
  Future<void> close() {
    _director.close();
    return _inner.close();
  }
}

/// Бот сценария: делает ровно тот ход, который записан в звене, и ждёт, пока сценарий до него дойдёт.
final class ScriptedBotAgent implements SeatAgent {
  /// Создаёт агента; [thinkTime] — пауза перед ходом, чтобы игрок успел увидеть свой ход, [pause] — пауза партии.
  ScriptedBotAgent(this._director, {this.thinkTime = const Duration(milliseconds: 700), MatchPause? pause})
    : _pause = pause ?? MatchPause();

  final ScenarioDirector _director;
  final MatchPause _pause;

  /// Пауза перед каждым ходом бота.
  final Duration thinkTime;

  @override
  Future<Intent?> decide(MatchState state, Seat seat) async {
    // Спрашивают после каждого хода, в том числе игрока: пока ход не бота, делать нечего.
    if (state.phase != MatchPhase.playing || state.turn != seat || state.choice != null) return null;
    final intent = await _director.botIntent(state, seat);
    if (intent != null && thinkTime > Duration.zero) await _pause.delay(thinkTime);
    return intent;
  }
}
