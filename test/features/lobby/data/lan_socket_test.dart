import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
    final big = Uint8List(200 * 1024);
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
      connector.connect(LanAddress(gameId: 'game-1', hosts: ['127.0.0.1'], port: port)),
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
