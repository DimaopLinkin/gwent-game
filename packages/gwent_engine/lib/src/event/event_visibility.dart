import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// События, которые можно отправить игроку [viewer]: скрытая информация соперника убрана
/// (раздел 4 сетевой спецификации).
List<GameEvent> eventsFor(List<GameEvent> events, Seat viewer) => [
  for (final event in events) ?_redact(event, viewer),
];

GameEvent? _redact(GameEvent event, Seat viewer) => switch (event) {
  CardsDrawn(:final seat, :final cards) when seat != viewer => CardsDrawnHidden(seat, cards.length),
  CardRedrawn(:final seat) when seat != viewer => null,
  HandRevealed(viewer: final shownTo) when shownTo != viewer => null,
  ChoiceRequested(:final seat, :final kind) when seat != viewer => ChoiceRequested(seat, kind, const []),
  _ => event,
};
