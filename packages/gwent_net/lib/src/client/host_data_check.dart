import 'package:gwent_engine/gwent_engine.dart';

/// Сверяет данные хоста со справочником клиента: карты, лидеры и место игрока.
///
/// Гость строит экран из проекции и событий, которые прислал хост. Хост может быть чужим (подделанное объявление,
/// QR-код) или модифицированным, и тогда в кадре окажется карта, которой нет в справочнике гостя: экран упал бы
/// на ней. Возвращает описание первой найденной проблемы или `null`, если данные годятся.
String? findHostDataProblem(
  CardCatalog catalog, {
  required PlayerView view,
  List<GameEvent> events = const [],
  Seat? seat,
}) {
  if (seat != null && view.viewer != seat) return 'проекция для места ${view.viewer.name}, а у игрока ${seat.name}';
  final shape = _implausible(view);
  if (shape != null) return shape;
  String? unknownCard(CardInstance card) =>
      catalog.card(card.cardId) == null ? 'карты «${card.cardId.value}» нет в справочнике' : null;
  String? unknownLeader(LeaderId leader) =>
      catalog.leader(leader) == null ? 'лидера «${leader.value}» нет в справочнике' : null;

  for (final side in [view.me, view.opponent]) {
    final problem = unknownLeader(side.leader) ?? _firstProblem(_sideCards(side), unknownCard);
    if (problem != null) return problem;
  }
  final inView = _firstProblem([
    for (final weather in view.weather) weather.card,
    ..._choiceCards(view.choice),
  ], unknownCard);
  if (inView != null) return inView;

  for (final event in events) {
    final problem = switch (event) {
      LeaderUsed(:final leader) => unknownLeader(leader),
      RoundEnded(:final board?) => _boardProblem(board, unknownCard, unknownLeader),
      _ => _firstProblem(_eventCards(event), unknownCard),
    };
    if (problem != null) return problem;
  }
  return null;
}

/// Предел любого счётчика в проекции: честная партия до него не дотягивает, а экран строит виджеты по счётчикам.
const int _maxCount = 1000;

/// Числа и состав проекции, на которых экран гостя может зависнуть или упасть, даже если все карты известны.
String? _implausible(PlayerView view) {
  if (view.me.seat != view.viewer || view.opponent.seat != view.viewer.opponent) {
    return 'места сторон в проекции не совпадают с местом игрока';
  }
  if (view.round < 0 || view.round > _maxCount) return 'номер раунда ${view.round} вне допустимого';
  for (final side in [view.me, view.opponent]) {
    final problem = _implausibleSide(side);
    if (problem != null) return problem;
  }
  return null;
}

String? _implausibleSide(SideView side) {
  final counts = [side.handCount, side.deckCount, side.crystals, side.score];
  if (counts.any((count) => count < 0 || count > _maxCount)) return 'счётчик стороны вне допустимого';
  if (Row.values.any((row) => side.rows[row] == null)) return 'в проекции нет рядов стороны';
  for (final row in side.rows.values) {
    if (row.strength < 0 || row.strength > _maxCount * _maxCount) return 'сила ряда вне допустимого';
  }
  return null;
}

/// Поле из события конца раунда: на нём экран гостя показывает последний ход, поэтому оно проверяется как проекция.
String? _boardProblem(
  RoundBoard board,
  String? Function(CardInstance card) unknownCard,
  String? Function(LeaderId leader) unknownLeader,
) {
  for (final side in board.sides.values) {
    final problem =
        _implausibleSide(side) ?? unknownLeader(side.leader) ?? _firstProblem(_sideCards(side), unknownCard);
    if (problem != null) return problem;
  }
  return _firstProblem([for (final weather in board.weather) weather.card], unknownCard);
}

String? _firstProblem(Iterable<CardInstance> cards, String? Function(CardInstance card) check) {
  for (final card in cards) {
    final problem = check(card);
    if (problem != null) return problem;
  }
  return null;
}

Iterable<CardInstance> _sideCards(SideView side) sync* {
  yield* side.hand ?? const [];
  yield* side.discard;
  for (final row in side.rows.values) {
    for (final fieldCard in row.cards) {
      yield fieldCard.card;
    }
    yield* _slotCards(row.slot);
  }
}

Iterable<CardInstance> _slotCards(RowSlot? slot) => switch (slot) {
  CardSlot(:final card) => [card],
  LeaderHornSlot() || null => const [],
};

Iterable<CardInstance> _choiceCards(PendingChoice? choice) => [
  ?choice?.subject,
  for (final option in choice?.options ?? const <ChoiceOption>[]) ..._optionCards(option),
];

Iterable<CardInstance> _optionCards(ChoiceOption option) => switch (option) {
  CardOption(:final card) => [card],
  RowOption() || SeatOption() => const [],
};

/// Карты события. Каждое событие перечислено явно: новое событие движка не скомпилируется без решения о проверке.
Iterable<CardInstance> _eventCards(GameEvent event) => switch (event) {
  CardsDrawn(:final cards) || HandRevealed(:final cards) => cards,
  CardRedrawn(:final returned, :final drawn) => [returned, drawn],
  CardPlayed(:final card) ||
  UnitPlaced(:final card) ||
  CreatedCardPlaced(:final card) ||
  WeatherPlayed(:final card) ||
  CardDiscarded(:final card) ||
  CardLeftGame(:final card) ||
  CardTakenFromDiscard(:final card) ||
  UnitKept(:final card) ||
  UnitMoved(:final card) => [card],
  BerserkTransformed(:final berserk, :final into) => [berserk, into],
  SlotFilled(:final slot) => _slotCards(slot),
  UnitDecoyed(:final decoy, :final returned) => [decoy, returned],
  UnitsDestroyed(:final units) => [for (final unit in units) unit.card],
  ChoiceRequested(:final options) => [for (final option in options) ..._optionCards(option)],
  FirstPlayerChosen() ||
  DeckShuffled() ||
  CardsDrawnHidden() ||
  RedrawFinished() ||
  RoundStarted() ||
  TurnStarted() ||
  WeatherCleared() ||
  DiscardShuffledIntoDeck() ||
  LeaderUsed() ||
  Passed() ||
  RoundEnded() ||
  MatchEnded() => const [],
};
