import 'package:gwent_engine/src/cards/leader_ability.dart';
import 'package:gwent_engine/src/engine/internal/agile_optimizer.dart';
import 'package:gwent_engine/src/engine/internal/field_rules.dart';
import 'package:gwent_engine/src/engine/internal/legality.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/engine/internal/scorch_rules.dart';
import 'package:gwent_engine/src/engine/internal/weather_rules.dart';
import 'package:gwent_engine/src/engine/reject.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/effect.dart';
import 'package:gwent_engine/src/state/row_slot.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Активные способности лидеров (раздел 10). Способность делает всё, что может, и тратит ход,
/// даже если ничего не произошло.
final class LeaderActions {
  const LeaderActions(this._ctx, this._field, this._weather, this._scorch, this._legality, this._agile);

  final MatchContext _ctx;
  final FieldRules _field;
  final WeatherRules _weather;
  final ScorchRules _scorch;
  final Legality _legality;
  final AgileOptimizer _agile;

  Reject? use(Seat seat) {
    if (!_legality.leaderAvailable(seat)) return const Reject(RejectReason.leaderUnavailable);
    final player = _ctx.player(seat)..leaderUsed = true;
    _ctx.emit(LeaderUsed(seat, player.leader));
    final effects = _ctx.draft.effects..add(EndTurnEffect(seat));

    switch (_ctx.leaderAbility(seat)!) {
      case PlayWeatherFromDeckAbility(:final card):
        final index = player.deck.indexWhere((instance) => instance.cardId == card);
        if (index >= 0) _weather.play(seat, player.deck.removeAt(index));
      case ClearAllWeatherAbility():
        _weather.clear();
      case LeaderHornAbility(:final row):
        if (_field.slotFree(seat, row)) _field.fillSlot(seat, row, const LeaderHornSlot());
      case ScorchOpponentRowAbility(:final row, :final threshold):
        _scorch.row(seat.opponent, row, threshold);
      case RevealOpponentHandAbility(:final count):
        final hand = _ctx.player(seat.opponent).hand;
        final shown = hand.length <= count ? [...hand] : _ctx.pick(hand, count);
        _ctx.emit(HandRevealed(seat, List.unmodifiable(shown)));
      case TakeFromOpponentDiscardAbility():
        effects.add(TakeFromDiscardEffect(seat, seat.opponent));
      case ReturnFromDiscardAbility():
        effects.add(TakeFromDiscardEffect(seat, seat));
      case DiscardAndTakeFromDeckAbility(:final discard, :final take):
        if (take > 0) effects.add(TakeFromDeckEffect(seat, take));
        if (discard > 0) effects.add(DiscardFromHandEffect(seat, discard));
      case PickWeatherFromDeckAbility():
        effects.add(PickWeatherFromDeckEffect(seat));
      case OptimizeAgileAbility():
        _agile.optimize(seat);
      case ShuffleDiscardsIntoDecksAbility():
        for (final target in [seat, seat.opponent]) {
          final other = _ctx.player(target);
          other.deck.addAll(other.discard);
          other.discard.clear();
          _ctx.shuffle(other.deck);
          _ctx.emit(DiscardShuffledIntoDeck(target));
        }
      case DisableOpponentLeaderAbility() ||
          RandomMedicAbility() ||
          DoubleSpiesAbility() ||
          ExtraStartingCardsAbility() ||
          HalveWeatherAbility():
        throw StateError('Пассивную способность нельзя применить как ход');
    }
    return null;
  }
}
