import 'package:gwent_engine/src/cards/deck.dart';
import 'package:gwent_engine/src/engine/engine_result.dart';
import 'package:gwent_engine/src/engine/match_setup.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/intent/intent.dart';
import 'package:gwent_engine/src/rules/deck_violation.dart';
import 'package:gwent_engine/src/state/match_state.dart';
import 'package:gwent_engine/src/state/seat.dart';
import 'package:gwent_engine/src/view/player_view.dart';

/// Движок правил: детерминированные чистые функции над состоянием партии.
///
/// Контракт из сетевой спецификации: `apply(state, seat, intent) → (state, events) | Reject`
/// и `project(state, seat) → PlayerView`. Одинаковые сид и намерения дают одинаковую партию.
abstract interface class MatchEngine {
  /// Создаёт партию: проверяет колоды и выполняет подготовку до первого выбора игрока
  /// (пересдача или решение Скоя'таэлей).
  EngineResult start(MatchSetup setup);

  /// Применяет намерение игрока [seat]. Входное состояние не меняется.
  EngineResult apply(MatchState state, Seat seat, Intent intent);

  /// Что видит игрок [seat].
  PlayerView project(MatchState state, Seat seat);

  /// События, которые можно отправить игроку [seat].
  List<GameEvent> eventsFor(List<GameEvent> events, Seat seat);

  /// Нарушения правил сборки колоды; пустой список значит, что колода годится.
  List<DeckViolation> validateDeck(Deck deck);
}
