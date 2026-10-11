import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/engine/internal/board_score.dart';
import 'package:gwent_engine/src/engine/internal/field_rules.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/engine/internal/strength_calculator.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/field_card.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Способность «Надежда Aen Seidhe» (раздел 10): раскладка своих проворных обычных отрядов между ближним
/// и дальним рядом с наибольшей суммой силы этих рядов.
final class AgileOptimizer {
  AgileOptimizer(this._ctx, this._field, this._board) : _calculator = StrengthCalculator(_ctx.catalog);

  final MatchContext _ctx;
  final FieldRules _field;
  final BoardScore _board;
  final StrengthCalculator _calculator;

  /// Предел перебора: 2^n раскладок. В данных обычных проворных отрядов не больше 9 у фракции и 1 нейтрального,
  /// а чужие карты на поле игрока попадают только как шпионы, поэтому предел недостижим.
  static const int _maxAgile = 20;

  void optimize(Seat seat) {
    final rows = _ctx.player(seat).rows;
    // Порядок проворных карт для разбора ничьих: сначала ближний ряд, затем дальний, внутри ряда по выкладке.
    final agile = [
      for (final row in const [Row.melee, Row.ranged])
        for (final card in rows[row]!.cards)
          if (_ctx.isNormalUnit(card.card) && _ctx.unit(card.card)!.placement.row == null) (card: card, row: row),
    ];
    if (agile.isEmpty) return;
    if (agile.length > _maxAgile) {
      throw StateError('«Надежда Aen Seidhe»: ${agile.length} проворных карт, перебор рассчитан на $_maxAgile');
    }

    final current = [for (final entry in agile) entry.row];
    var best = <List<Row>>[];
    int? bestScore;
    var bestMoves = 0;
    for (var mask = 0; mask < 1 << agile.length; mask++) {
      final layout = [for (var i = 0; i < agile.length; i++) mask & (1 << i) == 0 ? Row.melee : Row.ranged];
      final score = _score(seat, agile.map((entry) => entry.card).toList(), layout);
      final moves = _moves(current, layout);
      if (bestScore == null || score > bestScore || (score == bestScore && moves < bestMoves)) {
        best = [layout];
        bestScore = score;
        bestMoves = moves;
      } else if (score == bestScore && moves == bestMoves) {
        best.add(layout);
      }
    }

    // Первая по порядку карта, размещённая в оставшихся раскладках по-разному, остаётся на месте.
    for (var i = 0; i < agile.length && best.length > 1; i++) {
      if (best.any((layout) => layout[i] != best.first[i])) {
        best = best.where((layout) => layout[i] == current[i]).toList();
      }
    }
    _apply(seat, agile.map((entry) => entry.card).toList(), current, best.first);
  }

  static int _moves(List<Row> from, List<Row> to) => [
    for (var i = 0; i < from.length; i++)
      if (from[i] != to[i]) i,
  ].length;

  /// Ряды после раскладки: оставшиеся на месте карты сохраняют порядок, передвинутые встают в конец.
  Map<Row, List<FieldCard>> _layoutRows(Seat seat, List<FieldCard> agile, List<Row> layout) {
    final rows = _ctx.player(seat).rows;
    final agileIds = {for (final card in agile) card.card.id};
    final result = <Row, List<FieldCard>>{};
    for (final row in const [Row.melee, Row.ranged]) {
      result[row] = [
        for (final card in rows[row]!.cards)
          if (!agileIds.contains(card.card.id) || layout[agile.indexOf(card)] == row) card,
      ];
    }
    for (var i = 0; i < agile.length; i++) {
      if (!result[layout[i]]!.contains(agile[i])) result[layout[i]]!.add(agile[i]);
    }
    return result;
  }

  int _score(Seat seat, List<FieldCard> agile, List<Row> layout) {
    final rows = _ctx.player(seat).rows;
    var total = 0;
    for (final MapEntry(key: row, value: cards) in _layoutRows(seat, agile, layout).entries) {
      final strengths = _calculator.row(cards, rows[row]!.slot, _board.conditions(seat, row));
      total += strengths.fold(0, (sum, strength) => sum + strength);
    }
    return total;
  }

  void _apply(Seat seat, List<FieldCard> agile, List<Row> current, List<Row> layout) {
    final rows = _ctx.player(seat).rows;
    for (final MapEntry(key: row, value: cards) in _layoutRows(seat, agile, layout).entries) {
      rows[row]!.cards
        ..clear()
        ..addAll(cards);
    }
    for (var i = 0; i < agile.length; i++) {
      if (current[i] != layout[i]) _ctx.emit(UnitMoved(seat, agile[i].card, from: current[i], to: layout[i]));
    }
    _field.transformBerserks();
  }
}
