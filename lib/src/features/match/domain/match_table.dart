import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Партия, как её видит это устройство: места, за которые ходят здешние игроки, их проекции и события.
///
/// Держатель состояния экрана работает только с этим интерфейсом и не знает, кто сидит напротив: второй игрок
/// на этом же телефоне, бот или игрок по сети. Местная партия ([LocalMatchTable]) считает ходы движком сама;
/// сетевая (позже, поверх `MatchClient` из `gwent_net`) получает проекции от хоста. Решение: ADR 0006.
abstract interface class MatchTable {
  /// Места, за которые ходят люди на этом устройстве: оба в hot-seat, одно против бота и по сети.
  Set<Seat> get localSeats;

  /// Обновления для здешних мест. Подписчик один (держатель состояния); обновления до подписки не теряются,
  /// первым приходит [ViewsChanged] с раздачей.
  Stream<TableUpdate> get updates;

  /// Отправляет намерение за здешнее место [seat]. Итог придёт в [updates]: новые проекции или [IntentRefused].
  ///
  /// Бросает [ArgumentError], если [seat] не здешнее место, и [StateError] после [close].
  void submit(Seat seat, Intent intent);

  /// Заканчивает работу со столом: поток [updates] закрывается, соперник больше не ходит.
  Future<void> close();
}

/// Обновление партии для здешнего места.
@immutable
sealed class TableUpdate {
  const TableUpdate();
}

/// Партия изменилась: новые проекции всех здешних мест сразу и события, которые видны каждому из них.
///
/// Проекции приходят вместе, чтобы экран hot-seat не видел одно место уже после хода, а другое ещё до него.
final class ViewsChanged extends TableUpdate {
  /// Создаёт обновление.
  ViewsChanged(Map<Seat, PlayerView> views, Map<Seat, List<GameEvent>> events)
    : views = Map.unmodifiable(views),
      events = Map.unmodifiable({
        for (final MapEntry(key: seat, value: seatEvents) in events.entries)
          seat: List<GameEvent>.unmodifiable(seatEvents),
      });

  /// Что каждое здешнее место видит теперь.
  final Map<Seat, PlayerView> views;

  /// События с прошлого обновления, уже отфильтрованные для каждого места (`MatchEngine.eventsFor`).
  final Map<Seat, List<GameEvent>> events;
}

/// Движок отклонил намерение здешнего места: для интерфейса это рассинхрон, состояние не изменилось.
final class IntentRefused extends TableUpdate {
  /// Создаёт обновление.
  const IntentRefused(this.seat, this.intent, this.reject);

  /// Чьё намерение.
  final Seat seat;

  /// Отклонённое намерение.
  final Intent intent;

  /// Почему.
  final Reject reject;
}

/// Партия не может продолжаться: соперник не смог сделать ход (ошибка бота или движка) или связь потеряна
/// насовсем.
final class TableFailed extends TableUpdate {
  /// Создаёт обновление.
  const TableFailed(this.error);

  /// Причина.
  final Object error;
}
