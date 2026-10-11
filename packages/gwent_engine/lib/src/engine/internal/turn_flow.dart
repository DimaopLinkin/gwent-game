import 'package:gwent_engine/src/engine/internal/legality.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/engine/internal/round_transition.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/match_outcome.dart';
import 'package:gwent_engine/src/state/match_phase.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Ходы, пасы и автопас (разделы 4 и 5 правил).
final class TurnFlow {
  const TurnFlow(this._ctx, this._rounds, this._legality);

  final MatchContext _ctx;
  final RoundTransition _rounds;
  final Legality _legality;

  bool get _bothPassed => Seat.values.every((seat) => _ctx.player(seat).passed);

  /// Начинает партию: раунд 1 начинает [starter].
  void startMatch(Seat starter) {
    _ctx.draft.phase = MatchPhase.playing;
    _rounds.startRound(starter, previousWinner: null);
  }

  /// Действие игрока [from] разрешено: ход переходит к сопернику, если тот не спасовал (раздел 4).
  void advanceTurn(Seat from) {
    if (_ctx.draft.phase != MatchPhase.playing) return;
    if (_bothPassed) {
      _rounds.endRound();
      return;
    }
    _beginTurn(_ctx.player(from.opponent).passed ? from : from.opponent);
  }

  /// Пас игрока; при автопасе [auto] = `true` (раздел 5).
  void pass(Seat seat, {required bool auto}) {
    _ctx.player(seat).passed = true;
    _ctx.draft.turn = null;
    _ctx.emit(Passed(seat, auto: auto));
    advanceTurn(seat);
  }

  /// После эффектов начала раунда: автопас обоих игроков, затем первый ход (раздел 6, шаг 6).
  void beginRoundTurns() {
    final starter = _ctx.draft.roundStarter!;
    for (final seat in [starter, starter.opponent]) {
      if (!_legality.hasAction(seat)) {
        _ctx.player(seat).passed = true;
        _ctx.emit(Passed(seat, auto: true));
      }
    }
    if (_bothPassed) {
      _rounds.endRound();
    } else {
      _beginTurn(_ctx.player(starter).passed ? starter.opponent : starter);
    }
  }

  /// Сдача: партия заканчивается победой соперника.
  void resign(Seat seat) => _rounds.finish(MatchOutcome(winner: seat.opponent, reason: MatchEndReason.resignation));

  void _beginTurn(Seat seat) {
    if (!_legality.hasAction(seat)) {
      pass(seat, auto: true);
      return;
    }
    _ctx.draft.turn = seat;
    _ctx.emit(TurnStarted(seat));
  }
}
