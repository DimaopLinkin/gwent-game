import 'dart:async';
import 'dart:io';

import 'package:gwent/src/features/lobby/data/web_socket_transport.dart';
import 'package:gwent_net/gwent_net.dart';

/// Сервер хоста в локальной сети: принимает WebSocket на пути `/gwent/<идентификатор партии>`.
///
/// Слушает все адреса (IPv4 и IPv6, если есть) на свободном порту. Запрос к другому пути или к другой партии
/// получает 404: гость с устаревшим адресом не попадёт в чужую партию, занявшую тот же порт.
final class LanServer {
  LanServer._(this._server, this.gameId) : port = _server.port {
    _server.listen(_onRequest, onError: _onServerError, onDone: _onServerDone);
  }

  /// Начинает слушать. [port] `0` — любой свободный.
  ///
  /// Бросает [SocketException], если порт занят или сеть недоступна.
  static Future<LanServer> bind({required String gameId, int port = 0}) async {
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv6, port);
    } on SocketException {
      // Без IPv6 в системе слушаем только IPv4.
      server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    }
    return LanServer._(server, gameId);
  }

  /// Путь WebSocket партии [gameId].
  static List<String> pathFor(String gameId) => ['gwent', gameId];

  final HttpServer _server;

  /// Партия, соединения к которой принимает сервер.
  final String gameId;

  /// Отмена подписки на соединения тоже закрывает сервер: принятые сокеты иначе некому отдать.
  late final StreamController<Transport> _connections = StreamController<Transport>(onCancel: close);
  final Completer<void> _done = Completer<void>();
  bool _closed = false;

  /// Завершается, когда сервер перестал принимать соединения: после [close] или если ОС закрыла сокет.
  Future<void> get done => _done.future;

  /// Порт, на котором слушает (или слушал) сервер.
  final int port;

  /// Принятые соединения. Поток закрывается после [close] или если ОС закрыла сокет сервера; отмена подписки
  /// закрывает сервер.
  Stream<Transport> get connections => _connections.stream;

  /// Перестаёт принимать соединения. Уже принятые остаются открытыми.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _done.complete();
    unawaited(_connections.close());
    await _server.close();
  }

  Future<void> _onRequest(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    final ours = segments.length == 2 && segments.first == 'gwent' && segments.last == gameId;
    if (_closed || !ours || !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      // Гость мог уже уйти: ошибка закрытия ответа ничего не меняет.
      request.response.close().ignore();
      return;
    }
    final WebSocket socket;
    try {
      socket = await WebSocketTransformer.upgrade(request);
    } on WebSocketException {
      return;
    } on HttpException {
      return;
    }
    if (_closed) {
      // Гость уже мог уйти: ошибка закрытия ничего не меняет.
      socket.close(WebSocketStatus.goingAway).ignore();
      return;
    }
    _connections.add(WebSocketTransport(socket));
  }

  void _onServerError(Object error) => unawaited(close());

  void _onServerDone() => unawaited(close());
}
