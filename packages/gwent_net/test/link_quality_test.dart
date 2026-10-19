import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/table.dart';

/// Нестабильная связь и «свернул приложение» (ADR 0020): сигналы раньше обрыва, который засчитывается через 9 с.
void main() {
  Future<Table> started() async {
    final table = Table(seed: 3);
    await table.start(skellige, northern);
    return table;
  }

  test('молчание дольше 5 с делает связь нестабильной у обоих, пока обрыв не засчитан', () async {
    final table = await started();
    expect(table.eventsOf<LinkQualityChanged>(table.guest), isEmpty);

    table.guestLink!.faults = const Faults(drop: 1);
    await table.scheduler.elapse(const Duration(seconds: 6));

    expect(table.guest.status, ConnectionStatus.online);
    expect(table.eventsOf<LinkQualityChanged>(table.guest), [const LinkQualityChanged(unstable: true)]);
    expect(
      table.eventsOf<OpponentPresenceChanged>(table.hostClient).last,
      const OpponentPresenceChanged(online: true, name: 'Гость', unstable: true),
    );
  });

  test('когда кадры снова идут, связь становится стабильной', () async {
    final table = await started();
    table.guestLink!.faults = const Faults(drop: 1);
    // Связь возвращается сразу, как только стала нестабильной: ближайший ping придёт раньше тайм-аута в 9 с.
    await table.waitFor(
      () => table.eventsOf<LinkQualityChanged>(table.guest).isNotEmpty,
      'связь не стала нестабильной',
    );
    table.guestLink!.faults = Faults.none;
    await table.scheduler.elapse(const Duration(seconds: 4));

    expect(table.guest.status, ConnectionStatus.online);
    expect(table.eventsOf<LinkQualityChanged>(table.guest).last, const LinkQualityChanged(unstable: false));
    expect(table.eventsOf<OpponentPresenceChanged>(table.hostClient).last.unstable, isFalse);
    expect(table.eventsOf<OpponentPresenceChanged>(table.hostClient).last.online, isTrue);
  });

  test('обрыв после молчания: гость отключён, а не нестабилен', () async {
    final table = await started();
    table.guestLink!.faults = const Faults(drop: 1);
    await table.scheduler.elapse(const Duration(seconds: 10));

    expect(table.guest.status, ConnectionStatus.offline);
    final last = table.eventsOf<OpponentPresenceChanged>(table.hostClient).last;
    expect(last.online, isFalse);
    expect(last.unstable, isFalse);
  });

  test('хост сообщает, что свернул приложение, и что вернулся', () async {
    final table = await started();
    table.host.setAway(Seat.one, away: true);
    await table.scheduler.flush();
    expect(
      table.eventsOf<OpponentPresenceChanged>(table.guest).last,
      const OpponentPresenceChanged(online: true, name: 'Хост', away: true),
    );

    table.host.setAway(Seat.one, away: false);
    await table.scheduler.flush();
    expect(table.eventsOf<OpponentPresenceChanged>(table.guest).last.away, isFalse);
  });

  test('одно и то же состояние не рассылается заново', () async {
    final table = await started();
    final before = table.eventsOf<OpponentPresenceChanged>(table.guest).length;
    table.host.setAway(Seat.one, away: false);
    await table.scheduler.flush();
    expect(table.eventsOf<OpponentPresenceChanged>(table.guest), hasLength(before));
  });
}
