import 'package:gwent_engine/src/cards/faction.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/cards/unit_ability.dart';
import 'package:gwent_engine/src/engine/internal/field_rules.dart';
import 'package:gwent_engine/src/engine/internal/legality.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
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

/// Ходы, пасы, раунды и перки фракций (разделы 4–7 и 11 правил).
final class TurnFlow {
  const TurnFlow(this._ctx, this._field, this._legality);

  /// Раунд, в начале которого срабатывает перк Скеллиге.
  static const int _skelligeRound = 3;

  /// Сколько карт возвращает перк Скеллиге.
  static const int _skelligeCards = 2;

  /// Сколько карт берёт игрок Королевств Севера после выигранного раунда.
  static const int _northernDraw = 1;

  final MatchContext _ctx;
  final FieldRules _field;
  final Legality _legality;

  bool get _bothPassed => Seat.values.every((seat) => _ctx.player(seat).passed);

  /// Начинает партию: раунд 1 начинает [starter].
  void startMatch(Seat starter) {
    _ctx.draft.phase = MatchPhase.playing;
    _startRound(starter, previousWinner: null);
  }

  /// Действие игрока [from] разрешено: ход переходит к сопернику, если тот не спасовал (раздел 4).
  void advanceTurn(Seat from) {
    if (_ctx.draft.phase != MatchPhase.playing) return;
    if (_bothPassed) {
      _endRound();
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
      _endRound();
    } else {
      _beginTurn(_ctx.player(starter).passed ? starter.opponent : starter);
    }
  }

  /// Сдача: партия заканчивается победой соперника.
  void resign(Seat seat) => _finish(MatchOutcome(winner: seat.opponent, reason: MatchEndReason.resignation));

  void _beginTurn(Seat seat) {
    if (!_legality.hasAction(seat)) {
      pass(seat, auto: true);
      return;
    }
    _ctx.draft.turn = seat;
    _ctx.emit(TurnStarted(seat));
  }

  void _endRound() {
    final draft = _ctx.draft;
    draft.turn = null;
    final scores = {for (final seat in Seat.values) seat: _field.score(seat)};
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
    _ctx.emit(RoundEnded(result));

    final alive = [
      for (final seat in Seat.values)
        if (_ctx.player(seat).crystals > 0) seat,
    ];
    if (alive.length < Seat.values.length) {
      _finish(MatchOutcome(winner: alive.singleOrNull, reason: MatchEndReason.crystals));
      return;
    }

    final starter = winner ?? draft.roundStarter!;
    final order = [starter, starter.opponent];
    for (final seat in order) {
      if (_ctx.player(seat).faction.perk == FactionPerk.keepRandomUnit) _keepRandomUnit(seat);
    }
    _clearField(order);
    for (final seat in Seat.values) {
      _ctx.player(seat).passed = false;
    }
    _startRound(starter, previousWinner: winner);
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

  /// Перк Чудовищ: случайная карта отряда своей стороны остаётся на поле (раздел 11).
  void _keepRandomUnit(Seat seat) {
    final candidates = [
      for (final MapEntry(key: row, value: draftRow) in _ctx.player(seat).rows.entries)
        for (var i = 0; i < draftRow.cards.length; i++)
          if (_ctx.unit(draftRow.cards[i].card) != null) (row, i),
    ];
    if (candidates.isEmpty) return;
    final (row, index) = candidates[_ctx.random(candidates.length)];
    final cards = _ctx.player(seat).rows[row]!.cards;
    cards[index] = cards[index].copyWith(kept: true);
    _ctx.emit(UnitKept(seat, row, cards[index].card));
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
    final weather = [..._ctx.draft.weather];
    if (weather.isNotEmpty) {
      _ctx.draft.weather.clear();
      _ctx.emit(const WeatherCleared());
      for (final card in weather) {
        _ctx.discard(card.owner, card.card);
      }
    }
    for (final (seat, row, created) in summons) {
      _field.placeCreated(seat, row, created);
    }
    _field.transformBerserks();
  }

  /// Начало раунда и его эффекты по порядку (раздел 6, шаг 5).
  void _startRound(Seat starter, {required Seat? previousWinner}) {
    final draft = _ctx.draft;
    draft
      ..round += 1
      ..roundStarter = starter
      ..turn = null;
    _ctx.emit(RoundStarted(draft.round, starter));

    if (previousWinner != null && _ctx.player(previousWinner).faction.perk == FactionPerk.drawOnRoundWin) {
      _ctx.draw(previousWinner, _northernDraw);
    }
    for (final seat in Seat.values) {
      for (final draftRow in _ctx.player(seat).rows.values) {
        for (var i = 0; i < draftRow.cards.length; i++) {
          if (draftRow.cards[i].kept) draftRow.cards[i] = draftRow.cards[i].copyWith(kept: false);
        }
      }
    }

    final revived = <(Seat, CardInstance)>[];
    if (draft.round == _skelligeRound) {
      for (final seat in [starter, starter.opponent]) {
        if (_ctx.player(seat).faction.perk == FactionPerk.reviveInFinalRound) {
          final discard = _ctx.player(seat).discard;
          final picked = _ctx.pick(discard.where(_ctx.isNormalUnit).toList(), _skelligeCards);
          discard.removeWhere(picked.contains);
          revived.addAll(picked.map((card) => (seat, card)));
        }
      }
    }
    draft.effects.add(const BeginTurnsEffect());
    for (final (seat, card) in revived.reversed) {
      draft.effects.add(EnterFieldEffect(seat, card, EntrySource.perk, row: _ctx.unit(card)!.placement.row));
    }
  }

  void _finish(MatchOutcome outcome) {
    _ctx.draft
      ..phase = MatchPhase.finished
      ..turn = null
      ..choice = null
      ..outcome = outcome
      ..effects.clear();
    _ctx.emit(MatchEnded(outcome));
  }
}
