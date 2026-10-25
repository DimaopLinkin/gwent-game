import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
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

/// Партия уже начата вне экрана (сетевая из лобби или собранная заранее): показать её.
///
/// Держатель становится владельцем стола и закроет его. Если партия на экране уже идёт, стол сразу закрывается.
final class MatchSessionOpened extends MatchEvent {
  /// Создаёт событие.
  const MatchSessionOpened(this.session);

  /// Начатая партия.
  final MatchSession session;
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

/// Знакомство показано: время вышло или игрок нажал на экран.
final class MatchIntroFinished extends MatchEvent {
  /// Создаёт событие.
  const MatchIntroFinished();
}

/// Жребий показан: время вышло или игрок нажал на экран.
final class MatchTossFinished extends MatchEvent {
  /// Создаёт событие.
  const MatchTossFinished();
}

/// Игрок просит реванш: та же партия с теми же колодами. Принимается только на экране итога местной партии.
final class MatchRematchRequested extends MatchEvent {
  /// Создаёт событие.
  const MatchRematchRequested();
}

/// Игрок открыл или закрыл паузу матча: пока она открыта, бот за столом не думает и не ходит.
final class MatchPauseChanged extends MatchEvent {
  /// Создаёт событие.
  const MatchPauseChanged({required this.paused});

  /// Пауза открыта.
  final bool paused;
}

/// Обновление со стола партии. Создаёт только сам держатель состояния.
final class MatchTableUpdated extends MatchEvent {
  /// Создаёт событие.
  const MatchTableUpdated(this.update);

  /// Обновление.
  final TableUpdate update;
}
