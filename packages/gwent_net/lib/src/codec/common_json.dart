import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/codec/json_reader.dart';
import 'package:gwent_net/src/codec/protocol_exception.dart';
import 'package:gwent_net/src/protocol/ruleset.dart';

// JSON общих значений движка: карты, колоды, выборы, отказы, итоги. Перечисления передаются по имени значения
// (`Seat.one` → "one"); переименование значения меняет протокол, это ловит тест с эталонным кадром.

/// Тип варианта в JSON (`"type"`).
const String typeKey = 'type';

Map<String, Object?> encodeCard(CardInstance card) => {'id': card.id.value, 'card': card.cardId.value};

CardInstance decodeCard(JsonReader r) => CardInstance(CardInstanceId(r.integer('id')), CardId(r.string('card')));

List<Map<String, Object?>> encodeCards(List<CardInstance> cards) => [for (final card in cards) encodeCard(card)];

Map<String, Object?> encodeDeck(Deck deck) => {
  'leader': deck.leader.value,
  'cards': [for (final card in deck.cards) card.value],
};

Deck decodeDeck(JsonReader r) => Deck(
  leader: LeaderId(r.string('leader')),
  cards: List.unmodifiable(r.values<String>('cards', 'строка').map(CardId.new)),
);

Seat decodeSeat(JsonReader r, String key) => r.enumValue(key, Seat.values);

Seat? decodeOptionalSeat(JsonReader r, String key) => r.has(key) ? decodeSeat(r, key) : null;

Row decodeRow(JsonReader r, String key) => r.enumValue(key, Row.values);

Map<String, Object?> encodeOption(ChoiceOption option) => switch (option) {
  CardOption(:final card) => {typeKey: 'card', 'card': encodeCard(card)},
  RowOption(:final row) => {typeKey: 'row', 'row': row.name},
  SeatOption(:final seat) => {typeKey: 'seat', 'seat': seat.name},
};

ChoiceOption decodeOption(JsonReader r) => switch (r.string(typeKey)) {
  'card' => CardOption(decodeCard(r.object('card'))),
  'row' => RowOption(decodeRow(r, 'row')),
  'seat' => SeatOption(decodeSeat(r, 'seat')),
  final other => throw MalformedFrame('${r.path}.$typeKey: неизвестный вариант выбора «$other»'),
};

Map<String, Object?> encodeChoice(PendingChoice choice) => {
  'seat': choice.seat.name,
  'kind': choice.kind.name,
  'options': [for (final option in choice.options) encodeOption(option)],
  'subject': ?_encodeOptionalCard(choice.subject),
};

PendingChoice decodeChoice(JsonReader r) => PendingChoice(
  seat: decodeSeat(r, 'seat'),
  kind: r.enumValue('kind', ChoiceKind.values),
  options: r.objects('options', decodeOption),
  subject: r.optional('subject', decodeCard),
);

Map<String, Object?> encodeSlot(RowSlot slot) => switch (slot) {
  CardSlot(:final card) => {typeKey: 'card', 'card': encodeCard(card)},
  LeaderHornSlot() => {typeKey: 'leader_horn'},
};

RowSlot decodeSlot(JsonReader r) => switch (r.string(typeKey)) {
  'card' => CardSlot(decodeCard(r.object('card'))),
  'leader_horn' => const LeaderHornSlot(),
  final other => throw MalformedFrame('${r.path}.$typeKey: неизвестный слот «$other»'),
};

Map<String, Object?> encodeWeather(WeatherCard weather) => {
  'card': encodeCard(weather.card),
  'owner': weather.owner.name,
};

WeatherCard decodeWeather(JsonReader r) => WeatherCard(decodeCard(r.object('card')), decodeSeat(r, 'owner'));

Map<String, Object?> encodeRoundResult(RoundResult result) => {
  'round': result.round,
  'scores': {for (final MapEntry(:key, :value) in result.scores.entries) key.name: value},
  'winner': ?result.winner?.name,
};

RoundResult decodeRoundResult(JsonReader r) => RoundResult(
  round: r.integer('round'),
  scores: Map.unmodifiable({
    for (final (name, score) in r.integerEntries('scores')) enumByName(name, Seat.values, '${r.path}.scores'): score,
  }),
  winner: decodeOptionalSeat(r, 'winner'),
);

Map<String, Object?> encodeOutcome(MatchOutcome outcome) => {
  'winner': ?outcome.winner?.name,
  'reason': outcome.reason.name,
};

MatchOutcome decodeOutcome(JsonReader r) =>
    MatchOutcome(winner: decodeOptionalSeat(r, 'winner'), reason: r.enumValue('reason', MatchEndReason.values));

Map<String, Object?> encodeReject(Reject reject) => {
  'reason': reject.reason.name,
  'seat': ?reject.seat?.name,
  'violations': [for (final violation in reject.deckViolations) encodeViolation(violation)],
};

Reject decodeReject(JsonReader r) => Reject(
  r.enumValue('reason', RejectReason.values),
  seat: decodeOptionalSeat(r, 'seat'),
  deckViolations: r.objects('violations', decodeViolation),
);

Map<String, Object?> encodeViolation(DeckViolation violation) => switch (violation) {
  UnknownLeader(:final leader) => {typeKey: 'unknown_leader', 'leader': leader.value},
  LeaderNotDeckFaction(:final leader) => {typeKey: 'leader_not_deck_faction', 'leader': leader.value},
  UnknownCard(:final card) => {typeKey: 'unknown_card', 'card': card.value},
  WrongFaction(:final card) => {typeKey: 'wrong_faction', 'card': card.value},
  CreatedCardInDeck(:final card) => {typeKey: 'created_card_in_deck', 'card': card.value},
  TooManyCopies(:final card, :final count, :final max) => {
    typeKey: 'too_many_copies',
    'card': card.value,
    'count': count,
    'max': max,
  },
  TooFewUnitCards(:final count, :final min) => {typeKey: 'too_few_unit_cards', 'count': count, 'min': min},
  TooManySpecialCards(:final count, :final max) => {typeKey: 'too_many_special_cards', 'count': count, 'max': max},
};

DeckViolation decodeViolation(JsonReader r) => switch (r.string(typeKey)) {
  'unknown_leader' => UnknownLeader(LeaderId(r.string('leader'))),
  'leader_not_deck_faction' => LeaderNotDeckFaction(LeaderId(r.string('leader'))),
  'unknown_card' => UnknownCard(CardId(r.string('card'))),
  'wrong_faction' => WrongFaction(CardId(r.string('card'))),
  'created_card_in_deck' => CreatedCardInDeck(CardId(r.string('card'))),
  'too_many_copies' => TooManyCopies(CardId(r.string('card')), count: r.integer('count'), max: r.integer('max')),
  'too_few_unit_cards' => TooFewUnitCards(count: r.integer('count'), min: r.integer('min')),
  'too_many_special_cards' => TooManySpecialCards(count: r.integer('count'), max: r.integer('max')),
  final other => throw MalformedFrame('${r.path}.$typeKey: неизвестное нарушение колоды «$other»'),
};

Map<String, Object?> encodeRuleset(Ruleset ruleset) => {
  'id': ruleset.id,
  'hash': ruleset.hash,
  'engine': ruleset.engineVersion,
};

Ruleset decodeRuleset(JsonReader r) =>
    Ruleset(id: r.string('id'), hash: r.string('hash'), engineVersion: r.integer('engine'));

Map<String, Object?>? _encodeOptionalCard(CardInstance? card) => card == null ? null : encodeCard(card);
