import 'package:gwent_engine/src/cards/faction.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/cards/unit_ability.dart';
import 'package:gwent_engine/src/engine/internal/board_score.dart';
import 'package:gwent_engine/src/engine/internal/faction_perks.dart';
import 'package:gwent_engine/src/engine/internal/field_rules.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/engine/internal/projector.dart';
import 'package:gwent_engine/src/engine/internal/weather_rules.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/effect.dart';
import 'package:gwent_engine/src/state/entry_source.dart';
import 'package:gwent_engine/src/state/field_card.dart';
import 'package:gwent_engine/src/state/match_outcome.dart';
import 'package:gwent_engine/src/state/match_phase.dart';
import 'package:gwent_engine/src/state/round_result.dart';
import 'package:gwent_engine/src/state/row_slot.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Итог раунда, переход к следующему и конец партии (разделы 5.1, 6 и 7).
final class RoundTransition {
  const RoundTransition(this._ctx, this._field, this._score, this._weather, this._perks, this._projector);

  final MatchContext _ctx;
  final FieldRules _field;
  final BoardScore _score;
  final WeatherRules _weather;
  final FactionPerks _perks;
  final Projector _projector;

  /// Оба игрока спасовали: счёт, кристаллы, затем конец партии или следующий раунд.
  void endRound() {
    final draft = _ctx.draft;
    draft.turn = null;
    final board = _projector.board();
    final scores = {for (final seat in Seat.values) seat: _score.score(seat)};
    final winner = _roundWinner(scores);
    if (winner == null) {
      for (final seat in Seat.values) {
        _ctx.player(seat).crystals--;
      }
    } else {
      _ctx.player(winner.opponent).crystals--;
    }
    final result = RoundResult(round: draft.round, scores: Map.unmodifiable(scores), winner: winner);
    draft.history.add(result);
    _ctx.emit(RoundEnded(result, board: board));

    final alive = [
      for (final seat in Seat.values)
        if (_ctx.player(seat).crystals > 0) seat,
    ];
    if (alive.length < Seat.values.length) {
      finish(MatchOutcome(winner: alive.singleOrNull, reason: MatchEndReason.crystals));
      return;
    }

    final starter = winner ?? draft.roundStarter!;
    final order = [starter, starter.opponent];
    _perks.keepRandomUnits(order);
    _clearField(order);
    for (final seat in Seat.values) {
      _ctx.player(seat).passed = false;
    }
    startRound(starter, previousWinner: winner);
  }

  /// Начало раунда и его эффекты по порядку (раздел 6, шаг 5). Ходы начинаются после эффектов из стека.
  void startRound(Seat starter, {required Seat? previousWinner}) {
    final draft = _ctx.draft;
    draft
      ..round += 1
      ..roundStarter = starter
      ..turn = null;
    _ctx.emit(RoundStarted(draft.round, starter));

    _perks
      ..drawForRoundWinner(previousWinner)
      ..releaseKeptUnits();
    final revived = _perks.reviveUnits(draft.round, starter);
    draft.effects.add(const BeginTurnsEffect());
    for (final (seat, card) in revived.reversed) {
      draft.effects.add(EnterFieldEffect(seat, card, EntrySource.perk, row: _ctx.unit(card)!.placement.row));
    }
  }

  /// Конец партии.
  void finish(MatchOutcome outcome) {
    _ctx.draft
      ..phase = MatchPhase.finished
      ..turn = null
      ..choice = null
      ..outcome = outcome
      ..effects.clear();
    _ctx.emit(MatchEnded(outcome));
  }

  /// Победитель раунда; при ничьей побеждает единственный Нильфгаард (раздел 5.1).
  Seat? _roundWinner(Map<Seat, int> scores) {
    final one = scores[Seat.one]!;
    final two = scores[Seat.two]!;
    if (one != two) return one > two ? Seat.one : Seat.two;
    final tieWinners = [
      for (final seat in Seat.values)
        if (_ctx.player(seat).faction.perk == FactionPerk.winTies) seat,
    ];
    return tieWinners.length == 1 ? tieWinners.single : null;
  }

  /// Уборка поля между раундами (раздел 6, шаг 2). Приманка призывает свою карту после уборки.
  void _clearField(List<Seat> order) {
    final summons = <(Seat, Row, CardInstance)>[];
    for (final seat in order) {
      for (final MapEntry(key: row, value: draftRow) in _ctx.player(seat).rows.entries) {
        final kept = <FieldCard>[];
        for (final card in draftRow.cards) {
          if (card.kept) {
            kept.add(card);
            continue;
          }
          _field.leaveField(seat, card);
          if (_ctx.unit(card.card)?.ability case BaitAbility(:final summon)) {
            final created = _ctx.create(summon);
            summons.add((seat, _ctx.unit(created)!.placement.row ?? row, created));
          }
        }
        draftRow.cards
          ..clear()
          ..addAll(kept);
        if (draftRow.slot case CardSlot(:final card)) _ctx.discard(seat, card);
        draftRow.slot = null;
      }
    }
    if (_ctx.draft.weather.isNotEmpty) _weather.clear();
    for (final (seat, row, created) in summons) {
      _field.placeCreated(seat, row, created);
    }
    _field.transformBerserks();
  }
}
