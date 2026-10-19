import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/protocol/net_message.dart';

/// Что произошло у клиента партии: для держателя состояния экрана.
sealed class ClientEvent extends Value {
  const ClientEvent();
}

/// Хост выдал или вернул место.
final class Joined extends ClientEvent {
  const Joined(this.seat);

  final Seat seat;

  @override
  List<Object?> get props => [seat];
}

/// Хост не пустил; соединение закрыто, переподключаться с тем же билетом бессмысленно.
final class JoinRefused extends ClientEvent {
  const JoinRefused(this.reason, {required this.hostProtocol});

  final JoinRefusal reason;

  /// Версия протокола хоста.
  final int hostProtocol;

  @override
  List<Object?> get props => [reason, hostProtocol];
}

/// Связь с хостом потеряна; неотправленные намерения дождутся переподключения.
final class ConnectionLost extends ClientEvent {
  const ConnectionLost();

  @override
  List<Object?> get props => const [];
}

/// Проекция партии изменилась. [events] пуст, если хост прислал снимок.
final class ViewChanged extends ClientEvent {
  const ViewChanged(this.view, this.events);

  final PlayerView view;
  final List<GameEvent> events;

  @override
  List<Object?> get props => [view, events];
}

/// Хост не выполнил сообщение клиента.
final class ActionRefused extends ClientEvent {
  const ActionRefused(this.refusal, {required this.request});

  final Refusal refusal;

  /// Номер, который вернули `MatchClient.send` или `MatchClient.submitDeck` для отклонённого сообщения.
  final int request;

  @override
  List<Object?> get props => [refusal, request];
}

/// Соперник на связи или отключился.
final class OpponentPresenceChanged extends ClientEvent {
  const OpponentPresenceChanged({required this.online, required this.name, this.unstable = false, this.away = false});

  final bool online;

  /// Имя соперника.
  final String name;

  /// Хост давно не слышал соперника, хотя обрыв ещё не засчитан.
  final bool unstable;

  /// Соперник свернул приложение.
  final bool away;

  @override
  List<Object?> get props => [online, name, unstable, away];
}

/// Связь этого клиента с хостом стала нестабильной (хост молчит дольше обычного) или выровнялась.
final class LinkQualityChanged extends ClientEvent {
  const LinkQualityChanged({required this.unstable});

  final bool unstable;

  @override
  List<Object?> get props => [unstable];
}

/// Соперник изменил своё состояние в лобби: стадию и лидера выбранной колоды.
final class OpponentLobbyChanged extends ClientEvent {
  const OpponentLobbyChanged(this.stage, {this.leader});

  final LobbyStage stage;

  /// Лидер колоды соперника; `null`, пока колода не выбрана.
  final LeaderId? leader;

  @override
  List<Object?> get props => [stage, leader];
}

/// Оба игрока готовы: партия начнётся через [duration], если никто не отзовёт колоду.
final class CountdownStarted extends ClientEvent {
  const CountdownStarted(this.duration);

  final Duration duration;

  @override
  List<Object?> get props => [duration];
}

/// Отсчёт старта прерван.
final class CountdownCancelled extends ClientEvent {
  const CountdownCancelled();

  @override
  List<Object?> get props => const [];
}

/// Соперник ушёл из лобби; его место свободно.
final class OpponentLeft extends ClientEvent {
  const OpponentLeft();

  @override
  List<Object?> get props => const [];
}

/// Хост закрыл лобби: возвращаться некуда, переподключаться не нужно.
final class LobbyClosed extends ClientEvent {
  const LobbyClosed();

  @override
  List<Object?> get props => const [];
}
