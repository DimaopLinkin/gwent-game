import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:gwent/src/features/lobby/data/capped_socket.dart';
import 'package:gwent/src/features/lobby/data/web_socket_transport.dart';
import 'package:gwent_net/gwent_net.dart';

/// Сервер хоста в локальной сети: принимает WebSocket на пути `/gwent/<идентификатор партии>`.
///
/// Слушает все адреса (IPv4 и IPv6, если есть) на свободном порту. Запрос к другому пути или к другой партии
/// получает 404: гость с устаревшим адресом не попадёт в чужую партию, занявшую тот же порт.
final class LanServer {
  LanServer._(this._server, this.gameId, this._maxMessageBytes) : port = _server.port {
    _server.listen(_onRequest, onError: _onServerError, onDone: _onServerDone);
  }

  /// Начинает слушать. [port] `0` — любой свободный.
  ///
  /// Бросает [SocketException], если порт занят или сеть недоступна.
  static Future<LanServer> bind({
    required String gameId,
    int port = 0,
    int maxMessageBytes = defaultMaxMessageBytes,
  }) async {
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv6, port);
    } on SocketException {
      // Без IPv6 в системе слушаем только IPv4.
      server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    }
    return LanServer._(server, gameId, maxMessageBytes);
  }

  /// Сколько байт принимается без целого сообщения: вдвое больше кадра протокола (`EnvelopeCodec`, 64 КБ), с запасом
  /// на заголовки WebSocket. Большее сообщение обрывает соединение, пока оно не заняло память.
  static const int defaultMaxMessageBytes = 128 * 1024;

  /// Путь WebSocket партии [gameId].
  static List<String> pathFor(String gameId) => ['gwent', gameId];

  final HttpServer _server;
  final int _maxMessageBytes;

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
    final String? key;
    try {
      if (_closed || !ours || !WebSocketTransformer.isUpgradeRequest(request)) {
        _reject(request, HttpStatus.notFound);
        return;
      }
      key = request.headers.value('sec-websocket-key');
    } on HttpException {
      // Заголовок повторён: `value` не выбирает из нескольких.
      _reject(request, HttpStatus.badRequest);
      return;
    }
    if (key == null || key.length != _keyLength) {
      _reject(request, HttpStatus.badRequest);
      return;
    }
    final Socket raw;
    try {
      raw = await request.response.detachSocket(writeHeaders: false);
    } on StateError {
      return;
    }
    // Рукопожатие пишем сами: `WebSocketTransformer.upgrade` не даёт ограничить размер сообщения, а сжатие
    // (permessage-deflate) превращает мегабайт по сети в гигабайт в памяти. Расширений мы не предлагаем, поэтому
    // гость шлёт сообщения как есть, и размер сообщения не больше размера байт из сети.
    final accept = base64.encode(sha1.convert(utf8.encode('$key$_handshakeGuid')).bytes);
    raw.add(
      ascii.encode(
        'HTTP/1.1 101 Switching Protocols\r\n'
        'connection: Upgrade\r\n'
        'upgrade: websocket\r\n'
        'sec-websocket-accept: $accept\r\n'
        '\r\n',
      ),
    );
    if (_closed) {
      // Гость уже мог уйти: ошибка закрытия ничего не меняет.
      raw.destroy();
      return;
    }
    final budget = ByteBudget(_maxMessageBytes);
    // ignore: close_sinks, сокет закрывает WebSocketTransport, которому он передан.
    final socket = WebSocket.fromUpgradedSocket(
      CappedSocket(raw, budget),
      serverSide: true,
      compression: CompressionOptions.compressionOff,
    );
    _connections.add(WebSocketTransport(socket, budget: budget));
  }

  /// Длина ключа рукопожатия: 16 случайных байт в base64.
  static const int _keyLength = 24;

  /// Константа RFC 6455 для ответа на ключ рукопожатия.
  static const String _handshakeGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

  void _reject(HttpRequest request, int status) {
    request.response.statusCode = status;
    // Гость мог уже уйти: ошибка закрытия ответа ничего не меняет.
    request.response.close().ignore();
  }

  void _onServerError(Object error) => unawaited(close());

  void _onServerDone() => unawaited(close());
}
