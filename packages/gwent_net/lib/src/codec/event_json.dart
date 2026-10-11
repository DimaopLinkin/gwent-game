import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/codec/common_json.dart';
import 'package:gwent_net/src/codec/json_reader.dart';
import 'package:gwent_net/src/codec/protocol_exception.dart';

/// JSON события партии. Каждое событие перечислено явно: новое событие движка не скомпилируется без кодека.
Map<String, Object?> encodeEvent(GameEvent event) => switch (event) {
  FirstPlayerChosen(:final seat, :final byChoice) => {
    typeKey: 'first_player_chosen',
    'seat': seat.name,
    'by_choice': byChoice,
  },
  DeckShuffled(:final seat) => {typeKey: 'deck_shuffled', 'seat': seat.name},
  CardsDrawn(:final seat, :final cards) => {typeKey: 'cards_drawn', 'seat': seat.name, 'cards': encodeCards(cards)},
  CardsDrawnHidden(:final seat, :final count) => {typeKey: 'cards_drawn_hidden', 'seat': seat.name, 'count': count},
  CardRedrawn(:final seat, :final returned, :final drawn) => {
    typeKey: 'card_redrawn',
    'seat': seat.name,
    'returned': encodeCard(returned),
    'drawn': encodeCard(drawn),
  },
  RedrawFinished(:final seat) => {typeKey: 'redraw_finished', 'seat': seat.name},
  RoundStarted(:final round, :final starter) => {typeKey: 'round_started', 'round': round, 'starter': starter.name},
  TurnStarted(:final seat) => {typeKey: 'turn_started', 'seat': seat.name},
  CardPlayed(:final seat, :final card) => {typeKey: 'card_played', 'seat': seat.name, 'card': encodeCard(card)},
  UnitPlaced(:final side, :final row, :final card, :final source) => {
    typeKey: 'unit_placed',
    'side': side.name,
    'row': row.name,
    'card': encodeCard(card),
    'source': source.name,
  },
  CreatedCardPlaced(:final side, :final row, :final card) => {
    typeKey: 'created_card_placed',
    'side': side.name,
    'row': row.name,
    'card': encodeCard(card),
  },
  BerserkTransformed(:final side, :final row, :final berserk, :final into) => {
    typeKey: 'berserk_transformed',
    'side': side.name,
    'row': row.name,
    'berserk': encodeCard(berserk),
    'into': encodeCard(into),
  },
  SlotFilled(:final side, :final row, :final slot) => {
    typeKey: 'slot_filled',
    'side': side.name,
    'row': row.name,
    'slot': encodeSlot(slot),
  },
  WeatherPlayed(:final owner, :final card) => {
    typeKey: 'weather_played',
    'owner': owner.name,
    'card': encodeCard(card),
  },
  WeatherCleared() => {typeKey: 'weather_cleared'},
  UnitDecoyed(:final seat, :final row, :final decoy, :final returned) => {
    typeKey: 'unit_decoyed',
    'seat': seat.name,
    'row': row.name,
    'decoy': encodeCard(decoy),
    'returned': encodeCard(returned),
  },
  UnitsDestroyed(:final units) => {
    typeKey: 'units_destroyed',
    'units': [
      for (final unit in units) {'side': unit.side.name, 'row': unit.row.name, 'card': encodeCard(unit.card)},
    ],
  },
  CardDiscarded(:final owner, :final card) => {
    typeKey: 'card_discarded',
    'owner': owner.name,
    'card': encodeCard(card),
  },
  CardLeftGame(:final card) => {typeKey: 'card_left_game', 'card': encodeCard(card)},
  CardTakenFromDiscard(:final seat, :final from, :final card) => {
    typeKey: 'card_taken_from_discard',
    'seat': seat.name,
    'from': from.name,
    'card': encodeCard(card),
  },
  DiscardShuffledIntoDeck(:final seat) => {typeKey: 'discard_shuffled_into_deck', 'seat': seat.name},
  LeaderUsed(:final seat, :final leader) => {typeKey: 'leader_used', 'seat': seat.name, 'leader': leader.value},
  HandRevealed(:final viewer, :final cards) => {
    typeKey: 'hand_revealed',
    'viewer': viewer.name,
    'cards': encodeCards(cards),
  },
  Passed(:final seat, :final auto) => {typeKey: 'passed', 'seat': seat.name, 'auto': auto},
  ChoiceRequested(:final seat, :final kind, :final options) => {
    typeKey: 'choice_requested',
    'seat': seat.name,
    'kind': kind.name,
    'options': [for (final option in options) encodeOption(option)],
  },
  UnitKept(:final side, :final row, :final card) => {
    typeKey: 'unit_kept',
    'side': side.name,
    'row': row.name,
    'card': encodeCard(card),
  },
  RoundEnded(:final result) => {typeKey: 'round_ended', 'result': encodeRoundResult(result)},
  MatchEnded(:final outcome) => {typeKey: 'match_ended', 'outcome': encodeOutcome(outcome)},
  UnitMoved(:final side, :final card, :final from, :final to) => {
    typeKey: 'unit_moved',
    'side': side.name,
    'card': encodeCard(card),
    'from': from.name,
    'to': to.name,
  },
};

GameEvent decodeEvent(JsonReader r) {
  Seat seat([String key = 'seat']) => decodeSeat(r, key);
  Row row([String key = 'row']) => decodeRow(r, key);
  CardInstance card([String key = 'card']) => decodeCard(r.object(key));
  List<CardInstance> cards() => r.objects('cards', decodeCard);

  return switch (r.string(typeKey)) {
    'first_player_chosen' => FirstPlayerChosen(seat(), byChoice: r.boolean('by_choice')),
    'deck_shuffled' => DeckShuffled(seat()),
    'cards_drawn' => CardsDrawn(seat(), cards()),
    'cards_drawn_hidden' => CardsDrawnHidden(seat(), r.integer('count')),
    'card_redrawn' => CardRedrawn(seat(), returned: card('returned'), drawn: card('drawn')),
    'redraw_finished' => RedrawFinished(seat()),
    'round_started' => RoundStarted(r.integer('round'), seat('starter')),
    'turn_started' => TurnStarted(seat()),
    'card_played' => CardPlayed(seat(), card()),
    'unit_placed' => UnitPlaced(seat('side'), row(), card(), r.enumValue('source', EntrySource.values)),
    'created_card_placed' => CreatedCardPlaced(seat('side'), row(), card()),
    'berserk_transformed' => BerserkTransformed(seat('side'), row(), berserk: card('berserk'), into: card('into')),
    'slot_filled' => SlotFilled(seat('side'), row(), decodeSlot(r.object('slot'))),
    'weather_played' => WeatherPlayed(seat('owner'), card()),
    'weather_cleared' => const WeatherCleared(),
    'unit_decoyed' => UnitDecoyed(seat(), row(), decoy: card('decoy'), returned: card('returned')),
    'units_destroyed' => UnitsDestroyed(
      r.objects(
        'units',
        (unit) => DestroyedUnit(decodeSeat(unit, 'side'), decodeRow(unit, 'row'), decodeCard(unit.object('card'))),
      ),
    ),
    'card_discarded' => CardDiscarded(seat('owner'), card()),
    'card_left_game' => CardLeftGame(card()),
    'card_taken_from_discard' => CardTakenFromDiscard(seat(), seat('from'), card()),
    'discard_shuffled_into_deck' => DiscardShuffledIntoDeck(seat()),
    'leader_used' => LeaderUsed(seat(), LeaderId(r.string('leader'))),
    'hand_revealed' => HandRevealed(seat('viewer'), cards()),
    'passed' => Passed(seat(), auto: r.boolean('auto')),
    'choice_requested' => ChoiceRequested(
      seat(),
      r.enumValue('kind', ChoiceKind.values),
      r.objects('options', decodeOption),
    ),
    'unit_kept' => UnitKept(seat('side'), row(), card()),
    'round_ended' => RoundEnded(decodeRoundResult(r.object('result'))),
    'match_ended' => MatchEnded(decodeOutcome(r.object('outcome'))),
    'unit_moved' => UnitMoved(seat('side'), card(), from: row('from'), to: row('to')),
    final other => throw MalformedFrame('${r.path}.$typeKey: неизвестное событие «$other»'),
  };
}
