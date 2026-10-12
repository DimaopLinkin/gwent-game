import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Событие экрана партии.
@immutable
sealed class MatchEvent {
  const MatchEvent();
}

/// Игрок выбрал режим и колоды: начать партию.
final class MatchStartRequested extends MatchEvent {
  /// Создаёт событие.
  const MatchStartRequested(this.request);

  /// Режим и колоды.
  final LocalMatchRequest request;
}

/// Игрок, который держит телефон, сделал действие: карта, лидер, пас, пересдача, выбор или сдача.
final class MatchIntentSubmitted extends MatchEvent {
  /// Создаёт событие.
  const MatchIntentSubmitted(this.intent);

  /// Намерение для движка.
  final Intent intent;
}

/// Hot-seat: следующий игрок взял телефон и готов смотреть свою руку.
final class MatchHandoverAccepted extends MatchEvent {
  /// Создаёт событие.
  const MatchHandoverAccepted();
}

/// Обновление со стола партии. Создаёт только сам держатель состояния.
final class MatchTableUpdated extends MatchEvent {
  /// Создаёт событие.
  const MatchTableUpdated(this.update);

  /// Обновление.
  final TableUpdate update;
}
