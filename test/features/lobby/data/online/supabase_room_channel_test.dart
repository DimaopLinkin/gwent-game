import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/data/online/online_config.dart';
import 'package:gwent/src/features/lobby/data/online/room_message.dart';
import 'package:gwent/src/features/lobby/data/online/supabase_online_rooms.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent/src/features/lobby/domain/online_session_store.dart';

import '../../../../support/fakes.dart';
import '../../support/fake_supabase_server.dart';

final class _NoSessions implements OnlineSessionStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String session) async {}

  @override
  Future<void> clear() async {}
}

/// Канал комнаты против Realtime в памяти (протокол 2.0.0): вход в приватный канал, формат сообщений, обрыв.
/// Формат на проводе здесь описан по реализации `realtime_client`; с настоящим сервером он проверяется руками.
void main() {
  late FakeSupabaseServer server;
  late SupabaseOnlineRooms rooms;

  const topic = 'realtime:room:room-1';

  SupabaseOnlineRooms roomsFor(FakeSupabaseServer server, {Duration channelTimeout = const Duration(seconds: 5)}) =>
      SupabaseOnlineRooms(
        config: OnlineConfig(url: server.url, publishableKey: 'sb_publishable_test'),
        sessions: _NoSessions(),
        clock: FakeClock(DateTime.utc(2026, 10, 20, 12)),
        channelTimeout: channelTimeout,
      );

  setUp(() async {
    server = await FakeSupabaseServer.start();
    rooms = roomsFor(server);
  });

  tearDown(() async {
    await rooms.dispose();
    await server.stop();
  });

  test('вход в канал приватный и идёт с токеном игрока', () async {
    final channel = await rooms.connect('room-1');
    final socket = await server.socket;

    final join = socket.joins[topic]!;
    final config = join['config'] as Map<String, dynamic>;
    expect(config['private'], isTrue);
    expect((config['broadcast'] as Map<String, dynamic>)['self'], isFalse);
    expect(join['access_token'], isA<String>());
    await channel.close();
  });

  test('сообщения соперника приходят и в плоском виде, и в конверте; чужое отбрасывается', () async {
    final channel = await rooms.connect('room-1');
    final socket = await server.socket;
    final received = <RoomMessage>[];
    channel.messages.listen(received.add);

    socket.deliver(topic, {'type': 'broadcast', 'event': 'frame', 'cid': 9, 'from': 'host', 'd': 'плоский'});
    socket.deliver(topic, {
      'type': 'broadcast',
      'event': 'frame',
      'payload': {'cid': 9, 'from': 'host', 'd': 'в конверте'},
    });
    socket.deliver(topic, {'type': 'broadcast', 'event': 'bye', 'cid': 9, 'from': 'host'});
    socket.deliver(topic, {'type': 'broadcast', 'event': 'frame', 'cid': 'x', 'from': 'host', 'd': 'испорчено'});
    socket.deliver(topic, {'type': 'broadcast', 'event': 'other', 'cid': 9, 'from': 'host'});
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(received, [
      const FrameMessage(cid: 9, from: RoomSide.host, data: 'плоский'),
      const FrameMessage(cid: 9, from: RoomSide.host, data: 'в конверте'),
      const ByeMessage(cid: 9, from: RoomSide.host),
    ]);
    await channel.close();
  });

  test('отправка уходит событием broadcast с номером соединения и стороной', () async {
    final channel = await rooms.connect('room-1');
    final socket = await server.socket;

    channel.send(const FrameMessage(cid: 3, from: RoomSide.guest, data: '{"t":"hello"}'));
    channel.send(const ByeMessage(cid: 3, from: RoomSide.guest));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(socket.broadcasts, [
      {'type': 'broadcast', 'event': 'frame', 'cid': 3, 'from': 'guest', 'd': '{"t":"hello"}'},
      {'type': 'broadcast', 'event': 'bye', 'cid': 3, 'from': 'guest'},
    ]);
    await channel.close();
  });

  test('сервер не пустил в канал: сервис недоступен', () async {
    // Сокет появляется до входа, поэтому отказ включаем на первом же подключении.
    unawaited(server.socket.then((socket) => socket.refuseJoin = true));

    await expectLater(
      rooms.connect('room-1'),
      throwsA(isA<LobbyException>().having((error) => error.failure, 'failure', LobbyFailure.unavailable)),
    );
  });

  test('сервер не отвечает на вход: через срок сервис недоступен', () async {
    await rooms.dispose();
    rooms = roomsFor(server, channelTimeout: const Duration(milliseconds: 300));
    unawaited(server.socket.then((socket) => socket.ignoreJoin = true));

    await expectLater(
      rooms.connect('room-1'),
      throwsA(isA<LobbyException>().having((error) => error.failure, 'failure', LobbyFailure.unavailable)),
    );
  });

  test('сервер закрыл канал: канал сообщает о неполадке', () async {
    final channel = await rooms.connect('room-1');
    final socket = await server.socket;
    final trouble = channel.trouble.first;

    socket.closeChannel(topic);

    await trouble.timeout(const Duration(seconds: 5));
    await channel.close();
  });

  test('закрытый канал молчит и ничего не отправляет', () async {
    final channel = await rooms.connect('room-1');
    final socket = await server.socket;
    var done = false;
    channel.messages.listen((_) {}, onDone: () => done = true);

    await channel.close();
    await channel.close();
    channel.send(const ByeMessage(cid: 1, from: RoomSide.guest));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(done, isTrue);
    expect(socket.broadcasts, isEmpty);
  });
}
