import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/table.dart';

/// Хост сам решает, пускать ли гостя (ADR 0022): первый подключившийся не занимает место без его слова.
void main() {
  const settings = HostSettings(ruleset: ruleset, requireAdmission: true);

  Future<Table> knocked({HostSettings hostSettings = settings}) async {
    final table = Table(hostSettings: hostSettings)
      ..connectHost()
      ..connectGuest();
    await table.scheduler.flush();
    return table;
  }

  List<PendingGuest?> watch(Table table) {
    final seen = <PendingGuest?>[];
    table.host.pendingGuest.listen(seen.add);
    return seen;
  }

  test('гость ждёт: хост узнаёт его имя, соперники не видят друг друга', () async {
    final table = Table(hostSettings: settings);
    final seen = watch(table);
    table.connectHost();
    table.connectGuest();
    await table.scheduler.flush();
    expect(seen, [const PendingGuest(Seat.two, 'Гость')]);
    expect(table.host.pendingGuestNow, const PendingGuest(Seat.two, 'Гость'));
    expect(table.eventsOf<OpponentPresenceChanged>(table.hostClient), isEmpty);
    expect(table.eventsOf<OpponentPresenceChanged>(table.guest), isEmpty);
    expect(table.eventsOf<GuestAdmitted>(table.hostClient), hasLength(1), reason: 'свой клиент хоста пускается сам');
    expect(table.eventsOf<GuestAdmitted>(table.guest), isEmpty);
  });

  test('гость получает место сразу, чтобы связь жила, но колоду до решения хоста хост не принимает', () async {
    final table = await knocked();
    expect(table.guest.seat, Seat.two);
    table.guest.submitDeck(northern);
    await table.scheduler.flush();
    expect(table.eventsOf<OpponentLobbyChanged>(table.hostClient), isEmpty);
    table.host.admit(Seat.two);
    await table.scheduler.flush();
    table.hostClient.submitDeck(skellige);
    table.guest.submitDeck(northern);
    await table.waitFor(() => table.host.state != null, 'партия не началась');
  });

  test('«принять»: оба видят друг друга, гость узнаёт о приёме', () async {
    final table = await knocked();
    final seen = watch(table);
    table.host.admit(Seat.two);
    await table.scheduler.flush();
    expect(seen, [null]);
    expect(table.eventsOf<GuestAdmitted>(table.guest), hasLength(1));
    expect(table.eventsOf<OpponentPresenceChanged>(table.hostClient).single.name, 'Гость');
    expect(table.eventsOf<OpponentPresenceChanged>(table.guest).single.name, 'Хост');
    expect(table.host.pendingGuestNow, isNull);
  });

  test('«отклонить»: гость получает отказ, место свободно для другого', () async {
    final table = await knocked();
    table.host.decline(Seat.two);
    await table.scheduler.flush();
    expect(table.eventsOf<JoinRefused>(table.guest).single.reason, JoinRefusal.declined);
    expect(table.eventsOf<OpponentPresenceChanged>(table.hostClient), isEmpty);

    final other = table.newClient('Другой');
    table.connectGuest(other);
    await table.scheduler.flush();
    expect(table.host.pendingGuestNow, const PendingGuest(Seat.two, 'Другой'));
  });

  test('хост молчит: по истечении времени гость отклонён', () async {
    final table = await knocked();
    await table.scheduler.elapse(settings.admissionTimeout + const Duration(seconds: 1));
    expect(table.eventsOf<JoinRefused>(table.guest).single.reason, JoinRefusal.declined);
    expect(table.host.pendingGuestNow, isNull);
  });

  test('гость ушёл, пока хост думал: запрос снимается', () async {
    final table = await knocked();
    final seen = watch(table);
    await table.guestLink!.close();
    await table.scheduler.flush();
    expect(seen, [null]);
    expect(table.host.pendingGuestNow, isNull);
    await table.scheduler.elapse(const Duration(minutes: 3));
    expect(table.eventsOf<OpponentLeft>(table.hostClient), isEmpty, reason: 'хост и не знал о госте');
  });

  test('«принять» и «отклонить» для чужого или уже решённого места ничего не делают', () async {
    final table = await knocked();
    table.host
      ..admit(Seat.one)
      ..decline(Seat.one);
    table.host.admit(Seat.two);
    table.host.decline(Seat.two);
    await table.scheduler.flush();
    expect(table.eventsOf<JoinRefused>(table.guest), isEmpty);
    expect(table.eventsOf<GuestAdmitted>(table.guest), hasLength(1));
  });

  test('без требования хост пускает сразу, как раньше', () async {
    final table = Table(hostSettings: const HostSettings(ruleset: ruleset))
      ..connectHost()
      ..connectGuest();
    await table.scheduler.flush();
    expect(table.eventsOf<GuestAdmitted>(table.guest), hasLength(1));
    expect(table.host.pendingGuestNow, isNull);
  });
}
