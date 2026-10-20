import 'package:meta/meta.dart';

/// Сроки проверки связи в партии для вида сети (ADR 0026).
///
/// Wi-Fi быстр и стабилен, поэтому связь проверяется часто. Через интернет каждое сообщение идёт через сервер и
/// тарифицируется лимитом Realtime, а соединения чаще замирают (iOS замораживает свёрнутое приложение), поэтому
/// проверки реже, а терпения больше.
@immutable
final class LinkTimings {
  /// Создаёт сроки.
  const LinkTimings({
    required this.pingInterval,
    required this.linkTimeout,
    required this.unstableAfter,
    required this.reconnectWindow,
    required this.joinTimeout,
    required this.retryInterval,
  });

  /// Игра в локальной сети (Wi-Fi).
  static const LinkTimings local = LinkTimings(
    pingInterval: Duration(seconds: 3),
    linkTimeout: Duration(seconds: 9),
    unstableAfter: Duration(seconds: 5),
    reconnectWindow: Duration(minutes: 2),
    joinTimeout: Duration(seconds: 8),
    retryInterval: Duration(seconds: 2),
  );

  /// Игра через интернет.
  static const LinkTimings internet = LinkTimings(
    pingInterval: Duration(seconds: 10),
    linkTimeout: Duration(seconds: 30),
    unstableAfter: Duration(seconds: 15),
    reconnectWindow: Duration(minutes: 3),
    joinTimeout: Duration(seconds: 15),
    retryInterval: Duration(seconds: 6),
  );

  /// Как часто гость проверяет связь с хостом.
  final Duration pingInterval;

  /// Сколько собеседник может молчать, пока соединение считается живым. Больше [pingInterval] с запасом.
  final Duration linkTimeout;

  /// Сколько собеседник может молчать, пока связь ещё не считается нестабильной.
  final Duration unstableAfter;

  /// Сколько хост ждёт отключившегося гостя и сколько гость пытается вернуться к хосту.
  final Duration reconnectWindow;

  /// Сколько гость ждёт ответа хоста после соединения.
  final Duration joinTimeout;

  /// Как часто гость повторяет попытку вернуться к хосту. Через интернет каждая попытка идёт на сервер с лимитами.
  final Duration retryInterval;
}
