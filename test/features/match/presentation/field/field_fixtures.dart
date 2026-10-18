import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchMode;
import 'package:gwent_engine/gwent_engine.dart';

/// Карты из настоящего пакета для тестов поля: по признаку находит определение и выдаёт экземпляры с номерами.
final class TestCards {
  /// Создаёт выдачу карт из [content].
  TestCards(this.content);

  /// Контент партии.
  final GameContent content;

  int _next = 1;

  CardInstance _instance(CardId id) => CardInstance(CardInstanceId(_next++), id);

  CardDefinition _find(bool Function(CardDefinition definition) test) {
    final ids = [
      for (final card in content.pack.rules.squadCards) card.id,
      for (final card in content.pack.rules.specialCards) card.id,
    ];
    for (final id in ids) {
      final definition = content.catalog.card(CardId(id));
      if (definition != null && test(definition)) return definition;
    }
    throw StateError('В пакете нет подходящей карты');
  }

  /// Обычный отряд ряда [row] без способности.
  CardInstance unit(Row row) => _instance(
    _find(
      (card) =>
          card is UnitCardDefinition &&
          !card.isHero &&
          card.ability == null &&
          card.placement.rows.length == 1 &&
          card.placement.rows.single == row,
    ).id,
  );

  /// Проворный отряд: ближний или дальний ряд.
  CardInstance agile() => _instance(
    _find((card) => card is UnitCardDefinition && !card.isHero && card.placement.rows.length > 1).id,
  );

  /// Созданная карта (медведь, жетон Приманки): в колоду не входит.
  CardInstance created() => _instance(_find((card) => card is UnitCardDefinition && card.isCreated && !card.isHero).id);

  /// Шпион.
  CardInstance spy() => _instance(_find((card) => card is UnitCardDefinition && card.ability is SpyAbility).id);

  /// Медик.
  CardInstance medic() => _instance(_find((card) => card is UnitCardDefinition && card.ability is MedicAbility).id);

  /// Герой.
  CardInstance hero() => _instance(_find((card) => card is UnitCardDefinition && card.isHero).id);

  /// Особая карта со способностью типа [T].
  CardInstance special<T extends SpecialAbility>() =>
      _instance(_find((card) => card is SpecialCardDefinition && card.ability is T).id);

  /// Определение карты.
  CardDefinition definition(CardInstance card) => content.catalog.card(card.cardId)!;

  /// Базовая сила отряда.
  int strength(CardInstance card) => (definition(card) as UnitCardDefinition).strength;

  /// Лидер из пакета: первый по порядку.
  LeaderId get leader => LeaderId(content.pack.rules.leaderCards.first.id);

  /// Лидер с пассивной способностью.
  LeaderId get passiveLeader {
    for (final card in content.pack.rules.leaderCards) {
      final id = LeaderId(card.id);
      if (content.catalog.leader(id)?.ability.isPassive ?? false) return id;
    }
    throw StateError('В пакете нет лидера с пассивной способностью');
  }
}

/// Пустой ряд.
const RowView emptyRow = RowView(cards: [], slot: null, weather: false, strength: 0);

/// Ряд из карт [cards] с их базовой силой [strengths] (по умолчанию из определений) и признаками.
RowView rowOf(
  List<CardInstance> cards,
  TestCards source, {
  bool weather = false,
  RowSlot? slot,
  int? strength,
}) {
  final views = [for (final card in cards) FieldCardView(card: card, strength: source.strength(card))];
  return RowView(
    cards: views,
    slot: slot,
    weather: weather,
    strength: strength ?? views.fold(0, (sum, view) => sum + view.strength),
  );
}

/// Сторона для проекции: пустая, если не заданы поля.
SideView sideOf(
  TestCards source,
  Seat seat, {
  Map<Row, RowView> rows = const {},
  List<CardInstance>? hand,
  int? handCount,
  Set<CardInstanceId>? playable,
  List<CardInstance> discard = const [],
  bool passed = false,
  LeaderId? leader,
  bool leaderAvailable = true,
  bool leaderUsed = false,
  bool leaderDisabled = false,
  int score = 0,
  int crystals = 2,
  int deckCount = 20,
  int? redrawsLeft,
  bool redrawDone = false,
}) => SideView(
  seat: seat,
  leader: leader ?? source.leader,
  faction: Faction.skellige,
  leaderAvailable: leaderAvailable,
  leaderUsed: leaderUsed,
  leaderDisabled: leaderDisabled,
  crystals: crystals,
  passed: passed,
  hand: hand,
  handCount: handCount ?? hand?.length ?? 0,
  deckCount: deckCount,
  discard: discard,
  rows: {for (final row in Row.values) row: rows[row] ?? emptyRow},
  score: score,
  redrawDone: redrawDone,
  redrawsLeft: redrawsLeft,
  playable: playable ?? {for (final card in hand ?? const <CardInstance>[]) card.id},
);

/// Проекция партии глазами первого места; по умолчанию его ход.
PlayerView viewOf(
  TestCards source, {
  SideView? me,
  SideView? opponent,
  Seat? turn = Seat.one,
  MatchPhase phase = MatchPhase.playing,
  int round = 1,
  PendingChoice? choice,
  ChoiceKind? opponentChoosing,
  List<WeatherCard> weather = const [],
  List<RoundResult> history = const [],
  MatchOutcome? outcome,
}) => PlayerView(
  viewer: Seat.one,
  phase: phase,
  round: round,
  turn: turn,
  me: me ?? sideOf(source, Seat.one),
  opponent: opponent ?? sideOf(source, Seat.two, handCount: 7),
  weather: weather,
  choice: choice,
  opponentChoosing: opponentChoosing,
  history: history,
  outcome: outcome,
);

/// Состав партии для экранов: против бота (местное место одно) или hot-seat (оба места здешние).
///
/// Фракции и лидеры берутся из [factions] (по умолчанию Скеллиге у обоих, как в проекциях `sideOf`); колоды названы
/// «Колода 1» и «Колода 2».
MatchRoster rosterOf(
  TestCards source, {
  bool hotSeat = false,
  Map<Seat, Faction> factions = const {Seat.one: Faction.skellige, Seat.two: Faction.skellige},
  Map<Seat, LeaderId>? leaders,
}) => MatchRoster(
  mode: MatchMode.hotSeat,
  content: source.content,
  localSeats: hotSeat ? {Seat.one, Seat.two} : {Seat.one},
  players: {
    for (final seat in Seat.values)
      seat: MatchPlayer(
        seat: seat,
        faction: factions[seat] ?? Faction.skellige,
        leader: leaders?[seat] ?? source.leader,
        deckName: 'Колода ${seat.index + 1}',
      ),
  },
);
