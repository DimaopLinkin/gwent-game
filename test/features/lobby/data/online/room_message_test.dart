import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/data/online/room_message.dart';

void main() {
  test('кадр и закрытие превращаются в нагрузку и обратно', () {
    const frame = FrameMessage(cid: 42, from: RoomSide.guest, data: '{"t":"ping"}');
    const bye = ByeMessage(cid: 7, from: RoomSide.host);

    expect(frame.event, 'frame');
    expect(frame.payload, {'cid': 42, 'from': 'guest', 'd': '{"t":"ping"}'});
    expect(RoomMessage.tryParse(frame.event, frame.payload), frame);
    expect(bye.event, 'bye');
    expect(RoomMessage.tryParse(bye.event, bye.payload), bye);
  });

  test('нагрузка в конверте Realtime разбирается так же, как плоская', () {
    final wrapped = {
      'event': 'frame',
      'type': 'broadcast',
      'payload': {'cid': 1, 'from': 'host', 'd': 'x'},
    };

    expect(RoomMessage.tryParse('frame', wrapped), const FrameMessage(cid: 1, from: RoomSide.host, data: 'x'));
  });

  test('чужое и испорченное отбрасывается', () {
    final tooLong = 'a' * (RoomMessage.maxFrameLength + 1);
    final bad = <(String, Object?)>[
      ('frame', null),
      ('frame', 'строка'),
      ('frame', {'cid': 1, 'from': 'host'}),
      ('frame', {'cid': 1, 'from': 'host', 'd': 5}),
      ('frame', {'cid': 1, 'from': 'host', 'd': tooLong}),
      ('frame', {'cid': -1, 'from': 'host', 'd': 'x'}),
      ('frame', {'cid': 1 << 32, 'from': 'host', 'd': 'x'}),
      ('frame', {'cid': '1', 'from': 'host', 'd': 'x'}),
      ('frame', {'cid': 1, 'from': 'server', 'd': 'x'}),
      ('bye', {'cid': 1}),
      ('unknown', {'cid': 1, 'from': 'host'}),
    ];

    for (final (event, payload) in bad) {
      expect(RoomMessage.tryParse(event, payload), isNull, reason: '$event $payload');
    }
  });
}
