import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/codec/common_json.dart';
import 'package:gwent_net/src/codec/json_reader.dart';

/// JSON проекции партии для одного игрока.
Map<String, Object?> encodeView(PlayerView view) => {
  'viewer': view.viewer.wire,
  'phase': view.phase.wire,
  'round': view.round,
  'round_starter': ?view.roundStarter?.wire,
  'turn': ?view.turn?.wire,
  'me': _encodeSide(view.me),
  'opponent': _encodeSide(view.opponent),
  'weather': [for (final weather in view.weather) encodeWeather(weather)],
  'choice': ?_encodeOptionalChoice(view.choice),
  'opponent_choosing': ?view.opponentChoosing?.wire,
  'history': [for (final result in view.history) encodeRoundResult(result)],
  'outcome': ?_encodeOptionalOutcome(view.outcome),
};

PlayerView decodeView(JsonReader r) => PlayerView(
  viewer: decodeSeat(r, 'viewer'),
  phase: r.enumValue('phase', MatchPhase.values),
  round: r.integer('round'),
  roundStarter: decodeOptionalSeat(r, 'round_starter'),
  turn: decodeOptionalSeat(r, 'turn'),
  me: _decodeSide(r.object('me')),
  opponent: _decodeSide(r.object('opponent')),
  weather: r.objects('weather', decodeWeather),
  choice: r.optional('choice', decodeChoice),
  opponentChoosing: r.has('opponent_choosing') ? r.enumValue('opponent_choosing', ChoiceKind.values) : null,
  history: r.objects('history', decodeRoundResult),
  outcome: r.optional('outcome', decodeOutcome),
);

Map<String, Object?> _encodeSide(SideView side) => {
  'seat': side.seat.wire,
  'leader': side.leader.value,
  'faction': side.faction.wire,
  'leader_available': side.leaderAvailable,
  'leader_used': side.leaderUsed,
  'leader_disabled': side.leaderDisabled,
  'crystals': side.crystals,
  'passed': side.passed,
  'hand': ?_encodeOptionalCards(side.hand),
  'hand_count': side.handCount,
  'deck_count': side.deckCount,
  'discard': encodeCards(side.discard),
  'rows': {for (final MapEntry(:key, :value) in side.rows.entries) key.wire: _encodeRow(value)},
  'score': side.score,
  'redraws_left': ?side.redrawsLeft,
  'redraw_done': side.redrawDone,
  'playable': [for (final id in side.playable) id.value]..sort(),
};

SideView _decodeSide(JsonReader r) => SideView(
  seat: decodeSeat(r, 'seat'),
  leader: LeaderId(r.string('leader')),
  faction: r.enumValue('faction', Faction.values),
  leaderAvailable: r.boolean('leader_available'),
  leaderUsed: r.boolean('leader_used'),
  leaderDisabled: r.boolean('leader_disabled'),
  crystals: r.integer('crystals'),
  passed: r.boolean('passed'),
  hand: r.has('hand') ? r.objects('hand', decodeCard) : null,
  handCount: r.integer('hand_count'),
  deckCount: r.integer('deck_count'),
  discard: r.objects('discard', decodeCard),
  rows: Map.unmodifiable({
    for (final (name, row) in r.entries('rows')) enumByName(name, Row.values, '${r.path}.rows'): _decodeRow(row),
  }),
  score: r.integer('score'),
  redrawsLeft: r.optionalInteger('redraws_left'),
  redrawDone: r.boolean('redraw_done'),
  playable: Set.unmodifiable(r.values<int>('playable', 'целое число').map(CardInstanceId.new)),
);

Map<String, Object?> _encodeRow(RowView row) => {
  'cards': [
    for (final card in row.cards) {'card': encodeCard(card.card), 'strength': card.strength},
  ],
  'slot': ?_encodeOptionalSlot(row.slot),
  'weather': row.weather,
  'strength': row.strength,
};

RowView _decodeRow(JsonReader r) => RowView(
  cards: r.objects(
    'cards',
    (card) => FieldCardView(card: decodeCard(card.object('card')), strength: card.integer('strength')),
  ),
  slot: r.optional('slot', decodeSlot),
  weather: r.boolean('weather'),
  strength: r.integer('strength'),
);

List<Map<String, Object?>>? _encodeOptionalCards(List<CardInstance>? cards) =>
    cards == null ? null : encodeCards(cards);

Map<String, Object?>? _encodeOptionalChoice(PendingChoice? choice) => choice == null ? null : encodeChoice(choice);

Map<String, Object?>? _encodeOptionalOutcome(MatchOutcome? outcome) => outcome == null ? null : encodeOutcome(outcome);

Map<String, Object?>? _encodeOptionalSlot(RowSlot? slot) => slot == null ? null : encodeSlot(slot);
