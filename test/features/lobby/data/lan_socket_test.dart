import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/data/lan_connector.dart';
import 'package:gwent/src/features/lobby/data/lan_server.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent_net/gwent_net.dart';

/// Сервер и подключатель на настоящих сокетах через петлю 127.0.0.1.
void main() {
  late LanServer server;
  late StreamIterator<Transport> accepted;
  const connector = LanConnector(timeout: Duration(milliseconds: 500));

  setUp(() async {
    server = await LanServer.bind(gameId: 'game-1');
    accepted = StreamIterator(server.connections);
  });

  tearDown(() async {
    await accepted.cancel();
    await server.close();
  });

  LanAddress address({String gameId = 'game-1', List<String> hosts = const ['127.0.0.1']}) =>
      LanAddress(gameId: gameId, hosts: hosts, port: server.port);

  Future<(Transport, Transport)> connect() async {
    final guest = await connector.connect(address());
    expect(await accepted.moveNext(), isTrue);
    return (accepted.current, guest);
  }

  Uint8List bytes(List<int> values) => Uint8List.fromList(values);

  test('кадры идут в обе стороны по порядку и целиком', () async {
    final (host, guest) = await connect();
    final toHost = <List<int>>[];
    final toGuest = <List<int>>[];
    host.incoming.listen(toHost.add);
    guest.incoming.listen(toGuest.add);
    final big = Uint8List(100 * 1024);
    for (var i = 0; i < big.length; i++) {
      big[i] = i % 251;
    }
    guest
      ..send(bytes([1]))
      ..send(bytes([2, 2]))
      ..send(big);
    host.send(bytes([3]));
    await _until(() => toHost.length == 3 && toGuest.length == 1);
    expect(toHost.take(2), [
      [1],
      [2, 2],
    ]);
    expect(toHost.last, big, reason: 'большой кадр не режется и не склеивается');
    expect(toGuest, [
      [3],
    ]);
    await guest.close();
  });

  group('защита хоста от огромных сообщений', () {
    Future<WebSocket> rawClient({CompressionOptions compression = CompressionOptions.compressionDefault}) {
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      return WebSocket.connect(
        'ws://127.0.0.1:${server.port}/gwent/game-1',
        customClient: client,
        compression: compression,
      );
    }

    Future<List<Uint8List>> receivedBy(Transport host, {required Completer<void> done}) async {
      final received = <Uint8List>[];
      host.incoming.listen(received.add, onDone: done.complete);
      return received;
    }

    test('сообщение больше лимита рвёт соединение, не доходя до приложения', () async {
      // ignore: close_sinks, сервер рвёт соединение, дождаться его закрытия достаточно через drain.
      final socket = await rawClient();
      expect(await accepted.moveNext(), isTrue);
      final done = Completer<void>();
      final received = await receivedBy(accepted.current, done: done);
      socket.add(Uint8List(2 * 1024 * 1024));
      await done.future.timeout(const Duration(seconds: 10));
      expect(received, isEmpty);
      await socket.drain<void>().timeout(const Duration(seconds: 10));
    });

    test('сжатая «бомба» (мало байт по сети, много после распаковки) не распаковывается', () async {
      // ignore: close_sinks, сервер рвёт соединение, дождаться его закрытия достаточно через drain.
      final socket = await rawClient();
      expect(await accepted.moveNext(), isTrue);
      final done = Completer<void>();
      final received = await receivedBy(accepted.current, done: done);
      socket.add(Uint8List(64 * 1024 * 1024));
      await done.future.timeout(const Duration(seconds: 20));
      expect(received, isEmpty);
      await socket.drain<void>().timeout(const Duration(seconds: 10));
    });

    test('кадры допустимого размера идут подряд, лимит считается на сообщение, а не на соединение', () async {
      final socket = await rawClient();
      expect(await accepted.moveNext(), isTrue);
      final done = Completer<void>();
      final received = await receivedBy(accepted.current, done: done);
      for (var i = 0; i < 40; i++) {
        socket.add(Uint8List(60 * 1024));
      }
      await _until(() => received.length == 40);
      await socket.close();
    });
  });

  group('защита гостя от огромных сообщений хоста', () {
    /// Чужой «хост»: честное рукопожатие, а потом одно двоичное сообщение [size] байт. Возвращает порт.
    Future<(ServerSocket, int)> hostileHost(int size) async {
      final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      listener.listen((socket) async {
        final request = await utf8.decoder
            .bind(socket)
            .transform(const LineSplitter())
            .firstWhere(
              (line) => line.toLowerCase().startsWith('sec-websocket-key:'),
            );
        final key = request.substring(request.indexOf(':') + 1).trim();
        final accept = base64.encode(sha1.convert(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11')).bytes);
        socket.add(
          ascii.encode(
            'HTTP/1.1 101 Switching Protocols\r\nconnection: Upgrade\r\nupgrade: websocket\r\n'
            'sec-websocket-accept: $accept\r\n\r\n',
          ),
        );
        // Кадр без маски: 0x82 — конец сообщения, двоичные данные; 127 — длина в восьми байтах.
        final header = ByteData(10)
          ..setUint8(0, 0x82)
          ..setUint8(1, 127)
          ..setUint64(2, size);
        socket.add(header.buffer.asUint8List());
        socket.add(Uint8List(size));
        await socket.flush().onError((_, _) {});
      });
      return (listener, listener.port);
    }

    test('сообщение больше лимита рвёт соединение, не доходя до приложения', () async {
      final (listener, port) = await hostileHost(2 * 1024 * 1024);
      addTearDown(listener.close);
      final guest = await connector.connect(LanAddress(gameId: 'game-1', hosts: const ['127.0.0.1'], port: port));
      final received = <Uint8List>[];
      final done = Completer<void>();
      guest.incoming.listen(received.add, onDone: done.complete);
      await done.future.timeout(const Duration(seconds: 10));
      expect(received, isEmpty);
    });

    test('сообщение в пределах лимита доходит', () async {
      final (listener, port) = await hostileHost(60 * 1024);
      addTearDown(listener.close);
      final guest = await connector.connect(LanAddress(gameId: 'game-1', hosts: const ['127.0.0.1'], port: port));
      final received = await guest.incoming.first.timeout(const Duration(seconds: 10));
      expect(received, hasLength(60 * 1024));
      await guest.close();
    });
  });

  group('рукопожатие', () {
    Future<String> rawRequest(List<String> headers) async {
      final socket = await Socket.connect('127.0.0.1', server.port);
      socket.write(
        [
          'GET /gwent/game-1 HTTP/1.1',
          'Host: 127.0.0.1',
          'Connection: Upgrade',
          'Upgrade: websocket',
          'Sec-WebSocket-Version: 13',
          ...headers,
          '',
          '',
        ].join('\r\n'),
      );
      final reply = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 5));
      socket.destroy();
      return reply;
    }

    test('повторённый ключ и ключ неверной длины: 400, соединение не принимается', () async {
      expect(
        await rawRequest([
          'Sec-WebSocket-Key: AAAAAAAAAAAAAAAAAAAAAA==',
          'Sec-WebSocket-Key: BBBBBBBBBBBBBBBBBBBBBB==',
        ]),
        contains('400'),
      );
      expect(await rawRequest(['Sec-WebSocket-Key: short']), contains('400'));
    });

    test('честный ключ: 101', () async {
      expect(await rawRequest(['Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==']), contains('101'));
    });
  });

  test('закрытие любой стороной закрывает входящие у обеих', () async {
    for (final guestCloses in [true, false]) {
      final (host, guest) = await connect();
      final hostDone = Completer<void>();
      final guestDone = Completer<void>();
      host.incoming.listen(null, onDone: hostDone.complete);
      guest.incoming.listen(null, onDone: guestDone.complete);
      await (guestCloses ? guest : host).close();
      await Future.wait([hostDone.future, guestDone.future]).timeout(const Duration(seconds: 5));
      guest.send(bytes([1]));
      host.send(bytes([1]));
      await guest.close();
      await host.close();
    }
  });

  test('текстовое сообщение не из протокола: соединение закрывается', () async {
    final socket = await WebSocket.connect('ws://127.0.0.1:${server.port}/gwent/game-1');
    expect(await accepted.moveNext(), isTrue);
    final hostDone = Completer<void>();
    final received = <Uint8List>[];
    accepted.current.incoming.listen(received.add, onDone: hostDone.complete);
    socket.add('{"v":1}');
    await hostDone.future.timeout(const Duration(seconds: 5));
    await socket.drain<void>().timeout(const Duration(seconds: 5));
    expect(received, isEmpty);
    expect(socket.closeCode, WebSocketStatus.unsupportedData);
    await socket.close();
  });

  test('к чужой партии и не по WebSocket не подключиться', () async {
    await expectLater(
      connector.connect(address(gameId: 'game-2')),
      throwsA(isA<LobbyException>().having((e) => e.failure, 'failure', LobbyFailure.unreachable)),
    );
    final client = HttpClient();
    final response = await (await client.get('127.0.0.1', server.port, '/gwent/game-1')).close();
    expect(response.statusCode, HttpStatus.notFound);
    await response.drain<void>();
    client.close();
  });

  test('недоступные адреса пропускаются, IPv4 пробуется первым', () async {
    expect(LanConnector.orderedHosts(['fe80::1%en0', '::1', 'iphone.local', '192.168.1.5']), ['192.168.1.5', '::1']);
    final guest = await connector.connect(address(hosts: ['fe80::1%en0', '192.0.2.1', '127.0.0.1']));
    expect(await accepted.moveNext(), isTrue);
    await guest.close();
  });

  test('если не ответил ни один адрес, подключение недоступно', () async {
    final port = server.port;
    await server.close();
    await expectLater(
      connector.connect(LanAddress(gameId: 'game-1', hosts: const ['127.0.0.1'], port: port)),
      throwsA(isA<LobbyException>().having((e) => e.failure, 'failure', LobbyFailure.unreachable)),
    );
  });

  test('после закрытия сервера принятые соединения живут, новые не принимаются', () async {
    final (host, guest) = await connect();
    final received = <List<int>>[];
    host.incoming.listen(received.add);
    final connectionsDone = Completer<void>();
    unawaited(accepted.moveNext().then((more) => connectionsDone.complete()));
    await server.close();
    await connectionsDone.future.timeout(const Duration(seconds: 5));
    guest.send(bytes([7]));
    await _until(() => received.isNotEmpty);
    expect(received, [
      [7],
    ]);
    await expectLater(connector.connect(address()), throwsA(isA<LobbyException>()));
    await guest.close();
  });
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('условие не выполнилось за 5 с');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
