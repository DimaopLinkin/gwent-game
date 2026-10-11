import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/engine/internal/board_score.dart';
import 'package:gwent_engine/src/engine/internal/field_rules.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Казнь: уничтожение сильнейших обычных отрядов (разделы 9.3, 9.4, 10).
final class ScorchRules {
  const ScorchRules(this._ctx, this._score, this._field);

  final MatchContext _ctx;
  final BoardScore _score;
  final FieldRules _field;

  /// Казнь всего поля: сильнейшие обычные отряды у обоих игроков.
  void all() {
    final candidates = <(FieldTarget, int)>[
      for (final side in Seat.values)
        for (final row in Row.values) ..._normalUnits(side, row),
    ];
    _field.destroy(_strongest(candidates));
  }

  /// Казнь по ряду: если сила ряда не меньше [threshold], сильнейшие обычные отряды ряда.
  void row(Seat side, Row row, int threshold) {
    if (_score.rowTotal(side, row) < threshold) return;
    _field.destroy(_strongest(_normalUnits(side, row)));
  }

  List<(FieldTarget, int)> _normalUnits(Seat side, Row row) {
    final cards = _ctx.player(side).rows[row]!.cards;
    final strengths = _score.strengths(side, row);
    return [
      for (var i = 0; i < cards.length; i++)
        if (_ctx.isNormalUnit(cards[i].card)) ((side: side, row: row, card: cards[i]), strengths[i]),
    ];
  }

  static List<FieldTarget> _strongest(List<(FieldTarget, int)> candidates) {
    if (candidates.isEmpty) return const [];
    final max = candidates.map((candidate) => candidate.$2).reduce((a, b) => a > b ? a : b);
    return [
      for (final (target, strength) in candidates)
        if (strength == max) target,
    ];
  }
}
