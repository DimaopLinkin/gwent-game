import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Запрос к функции базы (`/rest/v1/rpc/<имя>`).
final class RpcCall {
  RpcCall(this.function, this.params, this.authorization);

  final String function;
  final Map<String, dynamic> params;

  /// Заголовок `Authorization` запроса.
  final String? authorization;
}

/// Подключение Realtime: канал и всё, что пришло по нему от клиента.
final class FakeRealtimeSocket {
  FakeRealtimeSocket(this._socket);

  final WebSocket _socket;

  /// Темы, в которые клиент вошёл, и нагрузка запроса входа.
  final Map<String, Map<String, dynamic>> joins = {};

  /// Нагрузки `broadcast`, которые прислал клиент.
  final List<Map<String, dynamic>> broadcasts = [];

  /// Тема, которой ответить отказом на вход.
  bool refuseJoin = false;

  /// Не отвечать на вход вообще (проект не отвечает).
  bool ignoreJoin = false;

  final Map<String, String> _joinRefs = {};

  /// Присылает клиенту broadcast в тему [topic], как это делает сервер, когда пишет другой участник канала.
  void deliver(String topic, Map<String, dynamic> payload) {
    _socket.add(jsonEncode([null, null, topic, 'broadcast', payload]));
  }

  /// Сообщает, что канал закрыт сервером.
  void closeChannel(String topic) {
    _socket.add(jsonEncode([_joinRefs[topic], null, topic, 'phx_close', <String, dynamic>{}]));
  }

  /// Рвёт соединение.
  Future<void> drop() => _socket.close();

  void _onFrame(Object? raw) {
    final frame = jsonDecode(raw! as String) as List<dynamic>;
    final joinRef = frame[0] as String?;
    final ref = frame[1] as String?;
    final topic = frame[2] as String;
    final event = frame[3] as String;
    final payload = frame[4];
    switch (event) {
      case 'phx_join':
        joins[topic] = Map<String, dynamic>.from(payload as Map);
        if (joinRef != null) _joinRefs[topic] = joinRef;
        if (ignoreJoin) return;
        final reply = refuseJoin
            ? {
                'status': 'error',
                'response': {'reason': 'Unauthorized'},
              }
            : {'status': 'ok', 'response': <String, dynamic>{}};
        _socket.add(jsonEncode([joinRef, ref, topic, 'phx_reply', reply]));
      case 'heartbeat':
        _socket.add(
          jsonEncode([
            null,
            ref,
            'phoenix',
            'phx_reply',
            {'status': 'ok', 'response': <String, dynamic>{}},
          ]),
        );
      case 'broadcast':
        broadcasts.add(Map<String, dynamic>.from(payload as Map));
      case 'phx_leave':
        joins.remove(topic);
        _socket.add(
          jsonEncode([
            joinRef,
            ref,
            topic,
            'phx_reply',
            {'status': 'ok', 'response': <String, dynamic>{}},
          ]),
        );
    }
  }
}

/// Проект Supabase в памяти для тестов клиента: анонимный вход, функции и таблица комнат по HTTP и Realtime по
/// WebSocket (протокол 2.0.0). Слушает на локальном порту, поэтому настоящий `SupabaseClient` ходит в него как в
/// сервис.
final class FakeSupabaseServer {
  FakeSupabaseServer._(this._http) {
    _http.listen(_handle);
  }

  /// Запускает сервер на свободном локальном порту.
  static Future<FakeSupabaseServer> start() async => FakeSupabaseServer._(await HttpServer.bind('127.0.0.1', 0));

  final HttpServer _http;

  /// Адрес проекта для `SupabaseClient`.
  String get url => 'http://127.0.0.1:${_http.port}';

  /// Ответ функции по имени; без него функция отвечает `{ok: true}` без комнаты.
  final Map<String, Object? Function(Map<String, dynamic> params)> functions = {};

  /// Статус и тело ответа на любой запрос функции; перекрывает [functions].
  (int, Object?)? rpcFailure;

  /// Через сколько отвечают функции: спящий проект не отвечает вовсе.
  Duration rpcDelay = Duration.zero;

  /// Ответ на выборку из `rooms`: строка или `null`, когда комнаты нет.
  Map<String, dynamic>? roomRow;

  /// Сколько анонимных входов выдано.
  int signUps = 0;

  /// Сколько раз обновляли сессию.
  int refreshes = 0;

  /// Анонимный вход отвечает ошибкой сервера.
  bool authFails = false;

  /// Все запросы к функциям.
  final List<RpcCall> rpcCalls = [];

  /// Подключения Realtime.
  final List<FakeRealtimeSocket> sockets = [];

  final Completer<void> _firstSocket = Completer<void>();

  /// Ждёт первого подключения Realtime.
  Future<FakeRealtimeSocket> get socket async {
    if (sockets.isEmpty) await _firstSocket.future;
    return sockets.first;
  }

  Future<void> stop() => _http.close(force: true);

  /// Сессия, как её выдаёт GoTrue: JWT с временем жизни [lifetime].
  Map<String, dynamic> session(String uid, {Duration lifetime = const Duration(hours: 1)}) {
    final exp = DateTime.now().add(lifetime).millisecondsSinceEpoch ~/ 1000;
    String part(Map<String, dynamic> value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': uid, 'exp': exp, 'role': 'authenticated'})}.sig';
    return {
      'access_token': token,
      'token_type': 'bearer',
      'expires_in': lifetime.inSeconds,
      'refresh_token': 'refresh-$uid',
      'user': {
        'id': uid,
        'aud': 'authenticated',
        'role': 'authenticated',
        'is_anonymous': true,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-10-20T12:00:00Z',
      },
    };
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = FakeRealtimeSocket(await WebSocketTransformer.upgrade(request));
      sockets.add(socket);
      if (!_firstSocket.isCompleted) _firstSocket.complete();
      socket._socket.listen(socket._onFrame, onError: (Object _) {}, cancelOnError: true);
      return;
    }
    final body = await utf8.decoder.bind(request).join();
    final response = request.response..headers.contentType = ContentType.json;
    void reply(int status, Object? data) {
      response
        ..statusCode = status
        ..write(jsonEncode(data));
    }

    if (path == '/auth/v1/signup') {
      if (authFails) {
        reply(500, {'code': 500, 'msg': 'сервис недоступен'});
      } else {
        signUps++;
        reply(200, session('player-$signUps'));
      }
    } else if (path == '/auth/v1/token') {
      refreshes++;
      reply(200, session('player-refreshed'));
    } else if (path.startsWith('/rest/v1/rpc/')) {
      final function = path.substring('/rest/v1/rpc/'.length);
      final params = body.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(body) as Map);
      rpcCalls.add(RpcCall(function, params, request.headers.value('authorization')));
      if (rpcDelay > Duration.zero) await Future<void>.delayed(rpcDelay);
      if (rpcFailure case (final status, final data)) {
        reply(status, data);
      } else {
        reply(200, functions[function]?.call(params) ?? {'ok': true});
      }
    } else if (path == '/rest/v1/rooms') {
      final row = roomRow;
      if (row == null) {
        reply(406, {'code': 'PGRST116', 'message': 'The result contains 0 rows', 'details': 'Results contain 0 rows'});
      } else {
        reply(200, row);
      }
    } else {
      reply(404, {'message': 'нет такого пути: $path'});
    }
    await response.close();
  }
}
