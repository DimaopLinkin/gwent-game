import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/table.dart';

/// Обрывы и переподключение (раздел 5 сетевой спецификации).
void main() {
  /// Партия в середине первого раунда: пересдача закончена, сделано несколько ходов, ходит [turn].
  Future<Table> midMatch({Seat? turn}) async {
    final table = Table(seed: 3);
    await table.start(skellige, northern);
    final bot = ViewBot();
    bool ready() {
      final state = table.host.state!;
      return state.phase == MatchPhase.playing &&
          table.journal.record!.moves.length >= 6 &&
          state.choice == null &&
          (turn == null || state.turn == turn);
    }

    while (!ready()) {
      final client = [table.hostClient, table.guest].firstWhere((client) => ViewBot.canAct(client.view!));
      await bot.act(table, client);
      await table.waitFor(() => table.converged, 'проекции не сошлись');
    }
    return table;
  }

  test('обрыв ставит партию на паузу, намерение без связи уходит после возвращения', () async {
    final table = await midMatch(turn: Seat.two);
    await table.guestLink!.cut();
    await table.scheduler.flush();
    expect(table.guest.status, ConnectionStatus.offline);
    expect(table.eventsOf<ConnectionLost>(table.guest), hasLength(1));
    expect(table.eventsOf<OpponentPresenceChanged>(table.hostClient).last.online, isFalse);

    // Пока гость отключён, ходить нельзя, а сдаться можно.
    final paused = table.hostClient.send(const Pass());
    await table.scheduler.flush();
    expect(
      table.eventsOf<ActionRefused>(table.hostClient).last.refusal,
      Refusal(RefusalCode.matchPaused, replyTo: paused),
    );

    // Намерение гостя без связи ждёт в очереди.
    final moves = table.journal.record!.moves.length;
    table.guest.send(const Pass());

    await table.scheduler.elapse(const Duration(seconds: 60));
    table.connectGuest();
    await table.waitFor(() => table.converged, 'гость не вернулся');
    expect(table.guest.status, ConnectionStatus.online);
    expect(table.eventsOf<Joined>(table.guest), [const Joined(Seat.two), const Joined(Seat.two)]);
    expect(table.eventsOf<OpponentPresenceChanged>(table.hostClient).last.online, isTrue);
    expect(table.journal.record!.moves.skip(moves), [const RecordedMove(Seat.two, Pass())]);

    await table.playOut();
    expect(table.host.state!.outcome, isNotNull);
  });

  test('ход хоста, который гость не получил, приходит событиями после возвращения', () async {
    final table = await midMatch(turn: Seat.one);
    // Обрыв, который хост замечает только по тайм-ауту: кадры теряются, соединение не закрыто.
    table.guestLink!.faults = const Faults(drop: 1);
    table.hostClient.send(const Pass());
    await table.scheduler.flush();
    expect(table.journal.record!.moves.last, const RecordedMove(Seat.one, Pass()));
    expect(table.guest.view, isNot(engine.project(table.host.state!, Seat.two)));

    // Тайм-аут связи: хост и гость закрывают молчащее соединение.
    await table.scheduler.elapse(const Duration(seconds: 10));
    expect(table.guest.status, ConnectionStatus.offline);
    expect(table.eventsOf<OpponentPresenceChanged>(table.hostClient).last.online, isFalse);

    final before = table.eventsOf<ViewChanged>(table.guest).length;
    table.connectGuest();
    await table.waitFor(() => table.converged, 'гость не догнал партию');
    final missed = table.eventsOf<ViewChanged>(table.guest).skip(before).toList();
    expect(
      missed.expand((event) => event.events),
      contains(const Passed(Seat.one, auto: false)),
      reason: 'пропущенные события дошли, а не только снимок',
    );
  });

  test('гость не вернулся за 2 минуты: он сдаётся, а вернувшись, видит итог', () async {
    final table = await midMatch();
    await table.guestLink!.cut();
    await table.scheduler.elapse(const Duration(seconds: 119));
    expect(table.host.state!.phase, MatchPhase.playing);
    await table.scheduler.elapse(const Duration(seconds: 2));
    expect(table.host.state!.outcome, const MatchOutcome(winner: Seat.one, reason: MatchEndReason.resignation));
    expect(table.journal.record!.moves.last, const RecordedMove(Seat.two, Resign()));
    expect(table.hostClient.view!.outcome, table.host.state!.outcome);

    table.connectGuest();
    await table.waitFor(() => table.converged, 'гость не увидел итог');
    expect(table.guest.view!.outcome, table.host.state!.outcome);
  });

  test('после перезапуска приложения гость возвращается по билету и получает снимок', () async {
    final table = await midMatch();
    final ticket = table.guest.ticket!;
    await table.guestLink!.cut();
    await table.guest.close();

    final restarted = table.guest = table.newClient('Гость', ticket: ticket);
    table.connectGuest(restarted);
    await table.waitFor(() => table.converged, 'перезапущенный гость не получил партию');
    final views = table.eventsOf<ViewChanged>(restarted);
    expect(views, hasLength(1));
    expect(views.single.events, isEmpty, reason: 'прежних сообщений у хоста нет, только снимок');
    expect(restarted.seat, Seat.two);

    await table.playOut();
    expect(table.host.state!.outcome, isNotNull);
  });

  test('перезапущенный гость отправляет намерение сразу после connect: оно не теряется', () async {
    final table = await midMatch(turn: Seat.one);
    final ticket = table.guest.ticket!;
    await table.guestLink!.cut();
    await table.guest.close();

    final restarted = table.guest = table.newClient('Гость', ticket: ticket);
    table.connectGuest(restarted);
    final pass = restarted.send(const Pass());
    final resign = restarted.send(const Resign());
    await table.waitFor(() => table.host.state!.phase == MatchPhase.finished && table.converged, 'сдача не дошла');
    expect(table.host.state!.outcome, const MatchOutcome(winner: Seat.one, reason: MatchEndReason.resignation));
    final refused = table.eventsOf<ActionRefused>(restarted).single;
    expect(refused.request, pass, reason: 'отказ ссылается на номер, который вернул send');
    expect(refused.refusal.reject, const Reject(RejectReason.notYourTurn));
    expect(resign, pass + 1);
  });

  test('перезапущенный в лобби гость меняет колоду: хост берёт новую', () async {
    final table = Table()
      ..connectHost()
      ..connectGuest();
    table.guest.submitDeck(northern);
    await table.scheduler.elapse(const Duration(seconds: 3));
    final ticket = table.guest.ticket!;
    await table.guestLink!.cut();
    await table.guest.close();

    final restarted = table.guest = table.newClient('Гость', ticket: ticket);
    table.connectGuest(restarted);
    restarted.submitDeck(scoiatael);
    await table.scheduler.flush();
    expect(table.eventsOf<ActionRefused>(restarted), isEmpty);
    table.hostClient.submitDeck(skellige);
    await table.waitFor(() => table.converged, 'партия не началась');
    expect(table.journal.record!.two, scoiatael);
  });

  test('потерянный welcome: место без подтверждения отдаётся новому подключению', () async {
    final table = Table()..connectHost();
    final link = table.connectGuest()..faults = const Faults(drop: 1);
    await table.scheduler.elapse(const Duration(seconds: 10));
    expect(link.dropped, greaterThan(0));
    expect(table.guest.status, ConnectionStatus.offline);
    expect(table.guest.ticket, isNull);

    table.connectGuest();
    await table.scheduler.flush();
    expect(table.guest.seat, Seat.two);
    expect(table.guest.status, ConnectionStatus.online);
  });

  test('в лобби место отключившегося освобождается через 2 минуты', () async {
    final table = Table()
      ..connectHost()
      ..connectGuest();
    await table.scheduler.flush();
    table.guest.submitDeck(northern);
    await table.scheduler.elapse(const Duration(seconds: 3));
    await table.guestLink!.cut();
    await table.scheduler.elapse(const Duration(minutes: 3));

    final newcomer = table.newClient('Новый');
    table.connectGuest(newcomer);
    await table.scheduler.flush();
    expect(newcomer.seat, Seat.two);
    expect(table.eventsOf<OpponentPresenceChanged>(table.hostClient).map((event) => event.online), [true, false, true]);

    table.connectGuest();
    await table.scheduler.flush();
    expect(table.eventsOf<JoinRefused>(table.guest).single.reason, JoinRefusal.unknownResumeToken);
  });

  test('подключение по тому же токену вытесняет старое соединение без паузы', () async {
    final table = await midMatch();
    final original = table.guest;
    // Второе соединение того же игрока, пока первое ещё живо (смена сети, полуоткрытый сокет).
    final twin = table.guest = table.newClient('Гость', ticket: original.ticket);
    table.connectGuest(twin);
    await table.waitFor(() => table.converged, 'новое соединение не заработало');
    expect(original.status, ConnectionStatus.offline, reason: 'хост закрыл старое соединение');
    expect(table.eventsOf<OpponentPresenceChanged>(table.hostClient).where((event) => !event.online), isEmpty);
    await table.playOut();
  });

  test('живое соединение не рвётся по тайм-ауту: ping каждые 3 с', () async {
    final table = Table()
      ..connectHost()
      ..connectGuest();
    await table.scheduler.elapse(const Duration(minutes: 5));
    expect(table.guest.status, ConnectionStatus.online);
    expect(table.hostClient.status, ConnectionStatus.online);
    expect(table.eventsOf<ConnectionLost>(table.guest), isEmpty);
  });

  test('после закрытия хоста клиенты видят обрыв, новые соединения закрываются', () async {
    final table = Table()
      ..connectHost()
      ..connectGuest();
    await table.scheduler.flush();
    await table.host.close();
    await table.scheduler.flush();
    expect(table.guest.status, ConnectionStatus.offline);
    expect(table.hostClient.status, ConnectionStatus.offline);

    table.connectGuest();
    await table.scheduler.flush();
    expect(table.guest.status, ConnectionStatus.offline);
  });
}
