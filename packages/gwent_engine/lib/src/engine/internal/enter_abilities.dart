import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/unit_ability.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/engine/internal/scorch_rules.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/effect.dart';
import 'package:gwent_engine/src/state/entry_source.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Способности отряда при выходе на поле (разделы 9.2, 9.4).
final class EnterAbilities {
  const EnterAbilities(this._ctx, this._scorch);

  final MatchContext _ctx;
  final ScorchRules _scorch;

  /// Способности при выходе карты [card], которую выложил игрок [player].
  void trigger(Seat player, CardInstance card, EntrySource source) {
    switch (_ctx.unit(card)?.ability) {
      case SpyAbility(:final draw):
        _ctx.draw(player, draw);
      case MedicAbility():
        _ctx.draft.effects.add(MedicEffect(player));
      case MusterAbility(:final summons):
        if (!source.isMuster) _muster(player, summons);
      case ScorchRowAbility(:final row, :final threshold):
        _scorch.row(player.opponent, row, threshold);
      case ScorchAllAbility():
        _scorch.all();
      case TightBondAbility() ||
          MoraleBoostAbility() ||
          UnitHornAbility() ||
          BaitAbility() ||
          BerserkAbility() ||
          MardremAuraAbility() ||
          null:
        break;
    }
  }

  /// Двойник: все карты [summons] из колоды, затем из руки выходят на поле.
  void _muster(Seat seat, List<CardId> summons) {
    final player = _ctx.player(seat);
    final summoned = <(CardInstance, EntrySource)>[];
    for (final id in summons) {
      for (final (zone, source) in [
        (player.deck, EntrySource.musterFromDeck),
        (player.hand, EntrySource.musterFromHand),
      ]) {
        summoned.addAll([
          for (final card in zone)
            if (card.cardId == id) (card, source),
        ]);
        zone.removeWhere((card) => card.cardId == id);
      }
    }
    // Стек: последний добавленный эффект выполняется первым, поэтому кладём в обратном порядке.
    for (final (card, source) in summoned.reversed) {
      _ctx.draft.effects.add(EnterFieldEffect(seat, card, source, row: _ctx.unit(card)!.placement.row));
    }
  }
}
