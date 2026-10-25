import 'package:gwent_engine/src/cards/card_definition.dart';
import 'package:gwent_engine/src/cards/special_ability.dart';
import 'package:gwent_engine/src/engine/internal/field_rules.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/engine/internal/scorch_rules.dart';
import 'package:gwent_engine/src/engine/internal/weather_rules.dart';
import 'package:gwent_engine/src/engine/reject.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/intent/intent.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/effect.dart';
import 'package:gwent_engine/src/state/entry_source.dart';
import 'package:gwent_engine/src/state/row_slot.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Розыгрыш карты из руки (разделы 9.2 и 9.3).
final class CardPlay {
  const CardPlay(this._ctx, this._field, this._weather, this._scorch);

  final MatchContext _ctx;
  final FieldRules _field;
  final WeatherRules _weather;
  final ScorchRules _scorch;

  /// Разыгрывает карту или возвращает причину отказа. Проверки идут до любых изменений.
  Reject? play(Seat seat, PlayCard intent) {
    final hand = _ctx.player(seat).hand;
    final index = hand.indexWhere((card) => card.id == intent.card);
    if (index < 0) return const Reject(RejectReason.cardNotInHand);
    final card = hand[index];

    switch (_ctx.definition(card)) {
      case UnitCardDefinition(:final placement):
        final fixed = placement.row;
        final row = intent.row ?? fixed;
        if (row == null) return const Reject(RejectReason.rowRequired);
        if (!placement.rows.contains(row)) return const Reject(RejectReason.invalidRow);
        _start(seat, card);
        _ctx.draft.effects.add(EnterFieldEffect(seat, card, EntrySource.hand, row: row));

      case SpecialCardDefinition(ability: WeatherAbility() || ClearWeatherAbility()):
        _start(seat, card);
        _weather.play(seat, card);

      case SpecialCardDefinition(ability: ScorchAbility()):
        _start(seat, card);
        _scorch.all();
        _ctx.discard(seat, card);

      case SpecialCardDefinition(ability: HornCardAbility() || MardremCardAbility()):
        final row = intent.row;
        if (row == null) return const Reject(RejectReason.rowRequired);
        _start(seat, card);
        // Слот занят: карта применяется вхолостую и сразу уходит в отбой (раздел 9.3).
        if (_field.slotFree(seat, row)) {
          _field.fillSlot(seat, row, CardSlot(card));
        } else {
          _ctx.discard(seat, card);
        }

      case SpecialCardDefinition(ability: DecoyAbility()):
        final targets = _field.decoyTargets(seat);
        if (targets.isEmpty) return const Reject(RejectReason.noValidTarget);
        final targetId = intent.target;
        if (targetId == null) return const Reject(RejectReason.targetRequired);
        final matches = targets.where((target) => target.card.card.id == targetId);
        if (matches.isEmpty) return const Reject(RejectReason.invalidTarget);
        _start(seat, card);
        _field.decoy(seat, card, matches.single);
    }
    return null;
  }

  /// Карта уходит из руки; после всех её эффектов ход перейдёт дальше.
  void _start(Seat seat, CardInstance card) {
    _ctx.player(seat).hand.remove(card);
    _ctx.emit(CardPlayed(seat, card));
    _ctx.draft.effects.add(EndTurnEffect(seat));
  }
}
