import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

/// Описание игрока для партии, собранной сразу в середине раунда.
final class Side {
  const Side({
    this.leader = 'foltest_clear',
    this.faction = Faction.northernRealms,
    this.hand = const [],
    this.deck = const [],
    this.discard = const [],
    this.melee = const [],
    this.ranged = const [],
    this.siege = const [],
    this.slots = const {},
    this.crystals = 2,
    this.passed = false,
    this.leaderUsed = false,
  });

  final String leader;
  final Faction faction;
  final List<String> hand;
  final List<String> deck;
  final List<String> discard;
  final List<String> melee;
  final List<String> ranged;
  final List<String> siege;

  /// Карта в слоте рога ряда; `'leader_horn'` означает рог лидера.
  final Map<Row, String> slots;
  final int crystals;
  final bool passed;
  final bool leaderUsed;
}

/// Партия на этапе ходов: раунд [round], ход игрока [turn]. Экземпляры нумеруются по порядку описания.
MatchState playing({
  Side one = const Side(),
  Side two = const Side(),
  Seat turn = Seat.one,
  Seat starter = Seat.one,
  int round = 1,
  List<(String, Seat)> weather = const [],
  Rng rng = const SeededRng(1),
}) {
  var next = 1;
  CardInstance instance(String id) => CardInstance(CardInstanceId(next++), CardId(id));
  List<CardInstance> zone(List<String> ids) => List.unmodifiable(ids.map(instance));

  PlayerState player(Side side, Side opponent) => PlayerState(
    leader: LeaderId(side.leader),
    faction: side.faction,
    crystals: side.crystals,
    deck: zone(side.deck),
    hand: zone(side.hand),
    discard: zone(side.discard),
    rows: {
      for (final (row, ids) in [(Row.melee, side.melee), (Row.ranged, side.ranged), (Row.siege, side.siege)])
        row: RowState(
          cards: List.unmodifiable(ids.map((id) => FieldCard(instance(id)))),
          slot: switch (side.slots[row]) {
            null => null,
            'leader_horn' => const LeaderHornSlot(),
            final id => CardSlot(instance(id)),
          },
        ),
    },
    leaderUsed: side.leaderUsed,
    leaderDisabled: catalog.leader(LeaderId(opponent.leader))!.ability is DisableOpponentLeaderAbility,
    passed: side.passed,
    redrawDone: true,
  );

  final players = {Seat.one: player(one, two), Seat.two: player(two, one)};
  return MatchState(
    phase: MatchPhase.playing,
    round: round,
    players: players,
    roundStarter: starter,
    turn: turn,
    weather: [for (final (id, owner) in weather) WeatherCard(instance(id), owner)],
    rng: rng,
    nextInstanceId: next,
  );
}

/// Применяет намерение и требует, чтобы движок его принял.
Accepted act(MatchEngine engine, MatchState state, Seat seat, Intent intent) {
  final result = engine.apply(state, seat, intent);
  if (result is! Accepted) fail('Намерение $intent отклонено: ${(result as Rejected).reject.reason}');
  return result;
}

/// Причина отказа; тест падает, если намерение принято.
RejectReason rejected(MatchEngine engine, MatchState state, Seat seat, Intent intent) => switch (engine.apply(
  state,
  seat,
  intent,
)) {
  Rejected(:final reject) => reject.reason,
  Accepted() => fail('Намерение $intent должно быть отклонено'),
};

/// Экземпляр карты [card] в зоне игрока: в руке, колоде, отбое или на поле.
CardInstanceId find(MatchState state, Seat seat, String card, {int nth = 0}) {
  final player = state.player(seat);
  final all = [
    ...player.hand,
    ...player.deck,
    ...player.discard,
    for (final row in player.rows.values) ...row.cards.map((field) => field.card),
  ];
  return all.where((instance) => instance.cardId == CardId(card)).elementAt(nth).id;
}

/// Названия карт ряда по порядку.
List<String> rowCards(MatchState state, Seat seat, Row row) => [
  for (final card in state.player(seat).rows[row]!.cards) card.card.cardId.value,
];

/// Названия карт зоны по порядку.
List<String> names(List<CardInstance> cards) => [for (final card in cards) card.cardId.value];
