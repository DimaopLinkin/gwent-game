import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/engine/internal/field_rules.dart';
import 'package:gwent_engine/src/engine/internal/legality.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/state/match_phase.dart';
import 'package:gwent_engine/src/state/seat.dart';
import 'package:gwent_engine/src/view/player_view.dart';

/// Строит проекцию партии для одного игрока.
final class Projector {
  const Projector(this._ctx, this._field, this._legality);

  final MatchContext _ctx;
  final FieldRules _field;
  final Legality _legality;

  PlayerView project(Seat viewer) {
    final draft = _ctx.draft;
    final choice = draft.choice;
    return PlayerView(
      viewer: viewer,
      phase: draft.phase,
      round: draft.round,
      roundStarter: draft.roundStarter,
      turn: draft.turn,
      me: _side(viewer, own: true),
      opponent: _side(viewer.opponent, own: false),
      weather: List.unmodifiable(draft.weather),
      choice: choice?.seat == viewer ? choice : null,
      opponentChoosing: choice != null && choice.seat != viewer ? choice.kind : null,
      history: List.unmodifiable(draft.history),
      outcome: draft.outcome,
    );
  }

  SideView _side(Seat seat, {required bool own}) {
    final draft = _ctx.draft;
    final player = _ctx.player(seat);
    final weatherRows = _field.weatherRows();
    final myTurn = draft.phase == MatchPhase.playing && draft.turn == seat && draft.choice == null;
    return SideView(
      seat: seat,
      leader: player.leader,
      faction: player.faction,
      leaderAvailable: _legality.leaderAvailable(seat),
      leaderUsed: player.leaderUsed,
      leaderDisabled: player.leaderDisabled,
      crystals: player.crystals,
      passed: player.passed,
      hand: own ? List.unmodifiable(player.hand) : null,
      handCount: player.hand.length,
      deckCount: player.deck.length,
      discard: List.unmodifiable(player.discard),
      rows: Map.unmodifiable({
        for (final row in Row.values) row: _row(seat, row, weather: weatherRows.contains(row)),
      }),
      score: _field.score(seat),
      redrawsLeft: own ? player.redrawsLeft : null,
      redrawDone: player.redrawDone,
      playable: own && myTurn
          ? Set.unmodifiable({
              for (final card in player.hand)
                if (_legality.canPlay(seat, card)) card.id,
            })
          : const {},
    );
  }

  RowView _row(Seat seat, Row row, {required bool weather}) {
    final draftRow = _ctx.player(seat).rows[row]!;
    final strengths = _field.strengths(seat, row);
    return RowView(
      cards: List.unmodifiable([
        for (var i = 0; i < draftRow.cards.length; i++)
          FieldCardView(card: draftRow.cards[i].card, strength: strengths[i], kept: draftRow.cards[i].kept),
      ]),
      slot: draftRow.slot,
      weather: weather,
      strength: strengths.fold(0, (sum, strength) => sum + strength),
    );
  }
}
