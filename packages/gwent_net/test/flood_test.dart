import 'dart:typed_data';

import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/table.dart';

/// Враждебный гость: сам пишет кадры и не подтверждает ничего из полученного (`ack` всегда 0).
final class _Flooder {
  _Flooder(this.table) {
    final (near, server) = InMemoryTransport.pair();
    _near = near;
    table.host.accept(server);
    near.incoming.listen((_) => frames++, onDone: () => closed = true);
  }

  static const _codec = EnvelopeCodec();

  final Table table;
  late final InMemoryTransport _near;
  int frames = 0;
  bool closed = false;
  int _seq = 0;

  void hello({String? token, String? matchId}) => _near.send(
    _codec.encode(
      Envelope(
        Hello(ruleset: ruleset, playerName: 'Враг', appVersion: 'x', resumeToken: token),
        matchId: matchId,
      ),
    ),
  );

  /// Намерение до начала партии: хост отвечает на каждое отказом, и отказы копятся в его очереди.
  void junk(int count) {
    for (var i = 0; i < count; i++) {
      _near.send(_codec.encode(Envelope(const IntentMessage(Pass()), seq: ++_seq)));
    }
  }

  void resend(int count) {
    final frame = _codec.encode(const Envelope(ResendRequest()));
    for (var i = 0; i < count; i++) {
      _near.send(Uint8List.fromList(frame));
    }
  }
}

/// Защита хоста от гостя, который не подтверждает сообщения и засыпает его просьбами переотправить.
void main() {
  const settings = HostSettings(ruleset: ruleset, maxUnacked: 50);

  Future<(Table, _Flooder)> joined() async {
    final table = Table(hostSettings: settings)..connectHost();
    final flooder = _Flooder(table)..hello();
    await table.scheduler.flush();
    return (table, flooder);
  }

  test('игрок, не подтверждающий сообщения, теряет соединение, очередь хоста не растёт', () async {
    final (table, flooder) = await joined();
    flooder.junk(200);
    await table.scheduler.flush();
    expect(flooder.closed, isTrue);
    expect(flooder.frames, lessThan(settings.maxUnacked + 10), reason: 'после закрытия хост ничего не шлёт');
  });

  test('просьбы переотправить не чаще одного раза за паузу', () async {
    final (table, flooder) = await joined();
    flooder.junk(30);
    await table.scheduler.flush();
    expect(flooder.closed, isFalse);
    final before = flooder.frames;
    flooder.resend(100);
    await table.scheduler.flush();
    final answered = flooder.frames - before;
    expect(answered, lessThanOrEqualTo(40), reason: 'одна переотправка очереди, а не сто');
    expect(answered, greaterThan(0));
  });

  test('после паузы переотправка снова работает', () async {
    final (table, flooder) = await joined();
    flooder.junk(30);
    await table.scheduler.flush();
    flooder.resend(1);
    await table.scheduler.flush();
    final first = flooder.frames;
    await table.scheduler.elapse(settings.resendCooldown + const Duration(milliseconds: 1));
    flooder.resend(1);
    await table.scheduler.flush();
    expect(flooder.frames, greaterThan(first));
  });

  test('вернувшийся после сброса очереди игрок получает место обратно', () async {
    final (table, flooder) = await joined();
    flooder.junk(200);
    await table.scheduler.flush();
    expect(flooder.closed, isTrue);
    final ticket = table.eventsOf<OpponentPresenceChanged>(table.hostClient);
    expect(ticket, isNotEmpty);
    final back = _Flooder(table)..hello(token: 'token-2', matchId: table.host.matchId);
    await table.scheduler.flush();
    expect(back.closed, isFalse, reason: 'токен принят: очередь сброшена, игрок начинает со снимка');
  });
}
