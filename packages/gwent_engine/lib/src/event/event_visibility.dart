import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// События, которые можно отправить игроку [viewer]: скрытая информация соперника убрана
/// (раздел 4 сетевой спецификации).
List<GameEvent> eventsFor(List<GameEvent> events, Seat viewer) => [
  for (final event in events) ?_redact(event, viewer),
];

/// Каждое событие перечислено явно: новое событие не уйдёт сопернику, пока для него не решена видимость.
GameEvent? _redact(GameEvent event, Seat viewer) => switch (event) {
  CardsDrawn(:final seat, :final cards) => seat == viewer ? event : CardsDrawnHidden(seat, cards.length),
  CardRedrawn(:final seat) => seat == viewer ? event : null,
  HandRevealed(viewer: final shownTo) => shownTo == viewer ? event : null,
  ChoiceRequested(:final seat, :final kind) => seat == viewer ? event : ChoiceRequested(seat, kind, const []),
  // Открытая информация: поле, отбои, погода, лидеры, счёт и число карт.
  FirstPlayerChosen() ||
  DeckShuffled() ||
  CardsDrawnHidden() ||
  RedrawFinished() ||
  RoundStarted() ||
  TurnStarted() ||
  CardPlayed() ||
  UnitPlaced() ||
  CreatedCardPlaced() ||
  BerserkTransformed() ||
  SlotFilled() ||
  WeatherPlayed() ||
  WeatherCleared() ||
  UnitDecoyed() ||
  UnitsDestroyed() ||
  CardDiscarded() ||
  CardLeftGame() ||
  CardTakenFromDiscard() ||
  DiscardShuffledIntoDeck() ||
  LeaderUsed() ||
  Passed() ||
  UnitKept() ||
  RoundEnded() ||
  MatchEnded() ||
  UnitMoved() => event,
};
