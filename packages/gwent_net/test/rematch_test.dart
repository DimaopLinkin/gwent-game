import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/table.dart';

/// Реванш после конца партии (ADR 0028): предложение, ответ, срок, уход соперника и возврат в лобби.
void main() {
  const window = Duration(seconds: 30);
  const settings = HostSettings(ruleset: ruleset);

  /// Партия сыграна: гость сдался.
  Future<Table> finished({HostSettings hostSettings = settings}) async {
    final table = Table(hostSettings: hostSettings);
    await table.start(northern, skellige);
    table.guest.send(const Resign());
    await table.waitFor(() => table.converged && table.host.state!.phase == MatchPhase.finished, 'сдача');
    return table;
  }

  List<RematchPhase> phases(Table table, MatchClient client) => [
    for (final event in table.eventsOf<RematchChanged>(client)) event.phase,
  ];

  test('пока никто не просил, статусов реванша нет', () async {
    final table = await finished();
    expect(table.eventsOf<RematchChanged>(table.hostClient), isEmpty);
    expect(table.eventsOf<RematchChanged>(table.guest), isEmpty);
  });

  test('просьба: просящий ждёт, соперник приглашён, окно называет хост', () async {
    final table = await finished();
    table.guest.requestRematch();
    await table.scheduler.flush();
    expect(phases(table, table.guest), [RematchPhase.asked]);
    expect(phases(table, table.hostClient), [RematchPhase.invited]);
    expect(table.eventsOf<RematchChanged>(table.guest).single.window, window);
  });

  test('оба согласны: партия сброшена до лобби, места и токены прежние', () async {
    final table = await finished();
    final tickets = (table.hostClient.ticket, table.guest.ticket);
    table.guest.requestRematch();
    table.hostClient.requestRematch();
    await table.scheduler.flush();
    expect(table.eventsOf<RematchStarted>(table.hostClient), hasLength(1));
    expect(table.eventsOf<RematchStarted>(table.guest), hasLength(1));
    expect(table.host.state, isNull);
    expect(table.guest.view, isNull);
    expect((table.hostClient.ticket, table.guest.ticket), tickets);
    // Оба снова выбирают колоду.
    final lobby = table.eventsOf<OpponentLobbyChanged>(table.guest).last;
    expect(lobby.stage, LobbyStage.choosing);
  });

  test('после согласия колоды выбирают заново и начинается вторая партия', () async {
    final table = await finished();
    table.guest.requestRematch();
    table.hostClient.requestRematch();
    await table.scheduler.flush();
    table.hostClient.submitDeck(skellige);
    table.guest.submitDeck(northern);
    await table.waitFor(() => table.host.state != null && table.converged, 'вторая партия не началась');
    expect(table.host.state!.phase, isNot(MatchPhase.finished));
    expect(table.guest.seat, Seat.two);
  });

  test('соперник молчит: время вышло, реванша нет', () async {
    final table = await finished();
    table.guest.requestRematch();
    await table.scheduler.elapse(window + const Duration(seconds: 1));
    expect(phases(table, table.guest), [RematchPhase.asked, RematchPhase.expired]);
    expect(phases(table, table.hostClient), [RematchPhase.invited, RematchPhase.expired]);
    table.hostClient.requestRematch();
    await table.scheduler.flush();
    expect(table.eventsOf<RematchStarted>(table.guest), isEmpty, reason: 'после срока согласие не принимается');
  });

  test('соперник согласился вовремя: срок больше не действует', () async {
    final table = await finished();
    table.guest.requestRematch();
    await table.scheduler.elapse(window - const Duration(seconds: 1));
    table.hostClient.requestRematch();
    await table.scheduler.elapse(const Duration(seconds: 5));
    expect(table.eventsOf<RematchStarted>(table.guest), hasLength(1));
    expect(phases(table, table.guest), [RematchPhase.asked]);
  });

  test('соперник ушёл: просящий узнаёт об этом, просьба в пустоту не принимается', () async {
    final table = await finished();
    table.guest.requestRematch();
    await table.scheduler.flush();
    await table.guestLink!.close();
    await table.scheduler.flush();
    expect(phases(table, table.hostClient).last, RematchPhase.opponentGone);
    final before = phases(table, table.hostClient).length;
    table.hostClient.requestRematch();
    await table.scheduler.flush();
    expect(phases(table, table.hostClient), hasLength(before));
    expect(table.eventsOf<RematchStarted>(table.hostClient), isEmpty);
  });

  test('соперник вернулся по токену: предложение снова открыто', () async {
    final table = await finished();
    table.hostClient.requestRematch();
    await table.scheduler.flush();
    await table.guestLink!.close();
    await table.scheduler.flush();
    expect(phases(table, table.hostClient).last, RematchPhase.opponentGone);
    table.connectGuest();
    await table.scheduler.flush();
    expect(phases(table, table.hostClient).last, RematchPhase.asked);
    expect(phases(table, table.guest).last, RematchPhase.invited);
    table.guest.requestRematch();
    await table.scheduler.flush();
    expect(table.eventsOf<RematchStarted>(table.hostClient), hasLength(1));
  });

  test('хост закрыл партию на экране итога: гость сразу узнаёт, что соперника нет', () async {
    final table = await finished();
    await table.host.close();
    await table.scheduler.flush();
    expect(phases(table, table.guest).last, RematchPhase.opponentGone);
  });

  test('до конца партии реванш не принимается', () async {
    final table = Table(hostSettings: settings);
    await table.start(northern, skellige);
    final request = table.guest.requestRematch();
    await table.scheduler.flush();
    final refusal = table.eventsOf<ActionRefused>(table.guest).single;
    expect(refusal.request, request);
    expect(refusal.refusal.code, RefusalCode.matchNotFinished);
    expect(table.eventsOf<RematchChanged>(table.hostClient), isEmpty);
  });

  test('повторная просьба того же игрока ничего не меняет', () async {
    final table = await finished();
    table.guest.requestRematch();
    table.guest.requestRematch();
    await table.scheduler.flush();
    expect(phases(table, table.guest), [RematchPhase.asked]);
    expect(table.eventsOf<RematchStarted>(table.guest), isEmpty);
  });

  test('вторая партия тоже кончается реваншем', () async {
    final table = await finished();
    for (var game = 0; game < 2; game++) {
      table.guest.requestRematch();
      table.hostClient.requestRematch();
      await table.scheduler.flush();
      table.hostClient.submitDeck(skellige);
      table.guest.submitDeck(northern);
      await table.waitFor(() => table.host.state != null && table.converged, 'партия ${game + 2} не началась');
      table.guest.send(const Resign());
      await table.waitFor(() => table.converged && table.host.state!.phase == MatchPhase.finished, 'сдача');
    }
    expect(table.eventsOf<RematchStarted>(table.guest), hasLength(2));
  });

  group('кодек', () {
    const codec = EnvelopeCodec();

    test('сообщения реванша проходят туда и обратно', () {
      for (final envelope in [
        const Envelope(RematchRequest(), seq: 3),
        const Envelope(RematchStatus(RematchPhase.invited, window: Duration(seconds: 30)), seq: 4),
        const Envelope(RematchStart(), seq: 5),
      ]) {
        expect(codec.decode(codec.encode(envelope)).message, envelope.message);
      }
    });

    test('срок реванша вне разумного отклоняется', () {
      final frame = codec.toJson(const Envelope(RematchStatus(RematchPhase.asked, window: Duration.zero), seq: 1))
        ..['p'] = {'phase': 'asked', 'ms': 99999999};
      expect(() => codec.fromJson(frame), throwsA(isA<MalformedFrame>()));
    });

    test('неизвестная фаза отклоняется', () {
      final frame = codec.toJson(const Envelope(RematchStatus(RematchPhase.asked, window: Duration.zero), seq: 1))
        ..['p'] = {'phase': 'dance', 'ms': 1};
      expect(() => codec.fromJson(frame), throwsA(isA<MalformedFrame>()));
    });
  });
}
