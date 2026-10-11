import 'package:gwent_engine/src/cards/faction.dart';
import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/random/rng.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/choice.dart';
import 'package:gwent_engine/src/state/effect.dart';
import 'package:gwent_engine/src/state/field_card.dart';
import 'package:gwent_engine/src/state/match_outcome.dart';
import 'package:gwent_engine/src/state/match_phase.dart';
import 'package:gwent_engine/src/state/match_state.dart';
import 'package:gwent_engine/src/state/player_state.dart';
import 'package:gwent_engine/src/state/round_result.dart';
import 'package:gwent_engine/src/state/row_slot.dart';
import 'package:gwent_engine/src/state/row_state.dart';
import 'package:gwent_engine/src/state/seat.dart';
import 'package:gwent_engine/src/state/weather_card.dart';

/// Изменяемая копия ряда на время одного `apply`.
final class DraftRow {
  DraftRow(this.cards, this.slot);

  DraftRow.from(RowState row) : this([...row.cards], row.slot);

  final List<FieldCard> cards;
  RowSlot? slot;

  RowState freeze() => RowState(cards: List.unmodifiable(cards), slot: slot);
}

/// Изменяемая копия игрока на время одного `apply`.
final class DraftPlayer {
  DraftPlayer({required this.leader, required this.faction, required this.crystals})
    : deck = [],
      hand = [],
      discard = [],
      rows = {for (final row in Row.values) row: DraftRow([], null)};

  DraftPlayer.from(PlayerState player)
    : leader = player.leader,
      faction = player.faction,
      crystals = player.crystals,
      deck = [...player.deck],
      hand = [...player.hand],
      discard = [...player.discard],
      rows = {for (final row in Row.values) row: DraftRow.from(player.rows[row]!)},
      leaderUsed = player.leaderUsed,
      leaderDisabled = player.leaderDisabled,
      passed = player.passed,
      redrawsLeft = player.redrawsLeft,
      redrawDone = player.redrawDone;

  final LeaderId leader;
  final Faction faction;
  int crystals;
  final List<CardInstance> deck;
  final List<CardInstance> hand;
  final List<CardInstance> discard;
  final Map<Row, DraftRow> rows;
  bool leaderUsed = false;
  bool leaderDisabled = false;
  bool passed = false;
  int redrawsLeft = 0;
  bool redrawDone = false;

  PlayerState freeze() => PlayerState(
    leader: leader,
    faction: faction,
    crystals: crystals,
    deck: List.unmodifiable(deck),
    hand: List.unmodifiable(hand),
    discard: List.unmodifiable(discard),
    rows: Map.unmodifiable({for (final MapEntry(:key, :value) in rows.entries) key: value.freeze()}),
    leaderUsed: leaderUsed,
    leaderDisabled: leaderDisabled,
    passed: passed,
    redrawsLeft: redrawsLeft,
    redrawDone: redrawDone,
  );
}

/// Изменяемая копия партии. `apply` работает с черновиком, а наружу отдаёт новое неизменяемое состояние;
/// входное состояние не меняется.
final class Draft {
  Draft({required this.players, required this.rng})
    : phase = MatchPhase.redraw,
      round = 0,
      nextInstanceId = 1,
      weather = [],
      effects = [],
      history = [];

  Draft.from(MatchState state)
    : phase = state.phase,
      round = state.round,
      players = {for (final seat in Seat.values) seat: DraftPlayer.from(state.player(seat))},
      roundStarter = state.roundStarter,
      turn = state.turn,
      weather = [...state.weather],
      choice = state.choice,
      effects = [...state.effects],
      history = [...state.history],
      outcome = state.outcome,
      rng = state.rng,
      nextInstanceId = state.nextInstanceId;

  MatchPhase phase;
  int round;
  final Map<Seat, DraftPlayer> players;
  Seat? roundStarter;
  Seat? turn;
  final List<WeatherCard> weather;
  PendingChoice? choice;
  final List<Effect> effects;
  final List<RoundResult> history;
  MatchOutcome? outcome;
  Rng rng;
  int nextInstanceId;

  DraftPlayer player(Seat seat) => players[seat]!;

  MatchState freeze() => MatchState(
    phase: phase,
    round: round,
    players: Map.unmodifiable({for (final seat in Seat.values) seat: player(seat).freeze()}),
    roundStarter: roundStarter,
    turn: turn,
    weather: List.unmodifiable(weather),
    choice: choice,
    effects: List.unmodifiable(effects),
    history: List.unmodifiable(history),
    outcome: outcome,
    rng: rng,
    nextInstanceId: nextInstanceId,
  );
}
