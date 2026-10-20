import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/data/online/room_message.dart';
import 'package:gwent/src/features/lobby/data/online/room_transport.dart';

void main() {
  late List<RoomMessage> sent;
  late List<RoomTransport> closed;
  late RoomTransport transport;

  setUp(() {
    sent = [];
    closed = [];
    transport = RoomTransport(cid: 5, side: RoomSide.guest, send: sent.add, onClosed: closed.add);
  });

  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

  test('кадры уходят в канал с номером соединения и стороной', () {
    transport.send(bytes('привет'));

    expect(sent, [const FrameMessage(cid: 5, from: RoomSide.guest, data: 'привет')]);
  });

  test('не UTF-8 в канал не уходит', () {
    transport.send(Uint8List.fromList([0xff, 0xfe]));

    expect(sent, isEmpty);
  });

  test('кадры собеседника приходят байтами', () async {
    final received = transport.incoming.first;

    transport.receive('привет');

    expect(utf8.decode(await received), 'привет');
  });

  test('закрытие шлёт bye один раз, сообщает о себе и глушит отправку', () async {
    await transport.close();
    await transport.close();
    transport.send(bytes('поздно'));

    expect(sent, [const ByeMessage(cid: 5, from: RoomSide.guest)]);
    expect(closed, [transport]);
    expect(transport.isClosed, isTrue);
    expect(await transport.incoming.isEmpty, isTrue);
  });

  test('закрытие собеседником и потеря канала молчат в канал', () {
    final other = RoomTransport(cid: 6, side: RoomSide.host, send: sent.add, onClosed: closed.add);

    transport.peerClosed();
    other.abandon();
    transport.receive('после закрытия');

    expect(sent, isEmpty);
    expect(closed, [transport, other]);
  });
}
