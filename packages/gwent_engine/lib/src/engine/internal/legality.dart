import 'package:gwent_engine/src/cards/card_definition.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/cards/special_ability.dart';
import 'package:gwent_engine/src/engine/internal/field_rules.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Какие действия доступны игроку (разделы 4 и 5: розыгрыш карт, лидер, автопас).
final class Legality {
  const Legality(this._ctx, this._field);

  final MatchContext _ctx;
  final FieldRules _field;

  /// Активную способность лидера можно применить.
  bool leaderAvailable(Seat seat) {
    final ability = _ctx.leaderAbility(seat);
    return !_ctx.player(seat).leaderUsed && ability != null && !ability.isPassive;
  }

  /// Карту можно сыграть: у неё есть допустимая цель (раздел 4).
  bool canPlay(Seat seat, CardInstance card) => switch (_ctx.definition(card)) {
    UnitCardDefinition() => true,
    SpecialCardDefinition(:final ability) => switch (ability) {
      WeatherAbility() || ClearWeatherAbility() || ScorchAbility() => true,
      HornCardAbility() || MardremCardAbility() => Row.values.any((row) => _field.slotFree(seat, row)),
      DecoyAbility() => _field.decoyTargets(seat).isNotEmpty,
    },
  };

  /// Есть ли у игрока действие, кроме паса (раздел 5, автопас).
  bool hasAction(Seat seat) => leaderAvailable(seat) || _ctx.player(seat).hand.any((card) => canPlay(seat, card));
}
