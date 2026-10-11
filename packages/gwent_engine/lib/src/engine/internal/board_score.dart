import 'package:gwent_engine/src/cards/card_definition.dart';
import 'package:gwent_engine/src/cards/leader_ability.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/cards/special_ability.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/engine/internal/strength_calculator.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Текущая сила карт, рядов и сторон с учётом погоды и пассивных способностей лидеров (раздел 8).
final class BoardScore {
  BoardScore(this._ctx) : _calculator = StrengthCalculator(_ctx.catalog);

  final MatchContext _ctx;
  final StrengthCalculator _calculator;

  /// Ряды под действующей погодой.
  Set<Row> weatherRows() => {
    for (final weather in _ctx.draft.weather)
      if (_ctx.definition(weather.card) case SpecialCardDefinition(ability: WeatherAbility(:final rows))) ...rows,
  };

  /// Текущая сила карт ряда в порядке выкладки.
  List<int> strengths(Seat side, Row row) {
    final draftRow = _ctx.player(side).rows[row]!;
    return _calculator.row(draftRow.cards, draftRow.slot, conditions(side, row));
  }

  /// Условия ряда для расчёта силы.
  RowConditions conditions(Seat side, Row row) => RowConditions(
    weather: weatherRows().contains(row),
    halveWeather: _ctx.leaderAbility(side) is HalveWeatherAbility,
    doubleSpies: _ctx.anyLeader((ability) => ability is DoubleSpiesAbility),
  );

  /// Сила ряда: сумма всех его карт, включая героев.
  int rowTotal(Seat side, Row row) => strengths(side, row).fold(0, (sum, strength) => sum + strength);

  /// Очки стороны: сумма трёх рядов.
  int score(Seat side) => Row.values.fold(0, (sum, row) => sum + rowTotal(side, row));
}
