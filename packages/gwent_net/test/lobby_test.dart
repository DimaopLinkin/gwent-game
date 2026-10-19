import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/table.dart';

/// Лобби перед партией: состояние игроков, готовность колодой, отсчёт старта, уход и закрытие (ADR 0019).
void main() {
  const delay = Duration(seconds: 3);
  const countdown = HostSettings(ruleset: ruleset, startDelay: delay);

  Table lobby({HostSettings? settings}) => Table(hostSettings: settings ?? countdown);

  Future<Table> joined({HostSettings? settings}) async {
    final table = lobby(settings: settings)
      ..connectHost()
      ..connectGuest();
    await table.scheduler.flush();
    return table;
  }

  group('состояние соперника', () {
    test('новый игрок сразу видит соперника выбирающим колоду', () async {
      final table = await joined();
      const choosing = OpponentLobbyChanged(LobbyStage.choosing);
      expect(table.eventsOf<OpponentLobbyChanged>(table.hostClient), [choosing]);
      expect(table.eventsOf<OpponentLobbyChanged>(table.guest), [choosing]);
    });

    test('стадия и лидер доходят до соперника, лидер виден до готовности', () async {
      final table = await joined();
      table.guest.reportLobbyStatus(LobbyStage.building);
      table.guest.reportLobbyStatus(LobbyStage.chosen, leader: skellige.leader);
      await table.scheduler.flush();
      expect(table.eventsOf<OpponentLobbyChanged>(table.hostClient).skip(1), [
        const OpponentLobbyChanged(LobbyStage.building),
        OpponentLobbyChanged(LobbyStage.chosen, leader: skellige.leader),
      ]);
    });

    test('готовность — это колода: соперник видит «готов» и лидера', () async {
      final table = await joined();
      table.guest.submitDeck(northern);
      await table.scheduler.flush();
      expect(
        table.eventsOf<OpponentLobbyChanged>(table.hostClient).last,
        OpponentLobbyChanged(LobbyStage.ready, leader: northern.leader),
      );
    });

    test('состояние «готов» в сообщении лобби на проводе недопустимо', () {
      const codec = EnvelopeCodec();
      final frame = codec.toJson(const Envelope(LobbyStatus(LobbyStage.chosen), seq: 1))..['p'] = {'stage': 'ready'};
      expect(() => codec.fromJson(frame), throwsA(isA<MalformedFrame>()));
    });

    test('вошедший позже узнаёт, что соперник уже готов', () async {
      final table = lobby()..connectHost();
      table.hostClient.submitDeck(skellige);
      await table.scheduler.flush();
      table.connectGuest();
      await table.scheduler.flush();
      expect(
        table.eventsOf<OpponentLobbyChanged>(table.guest).single,
        OpponentLobbyChanged(LobbyStage.ready, leader: skellige.leader),
      );
    });
  });

  group('отсчёт старта', () {
    test('оба готовы: оба слышат отсчёт, партия начинается по его окончании, не раньше', () async {
      final table = await joined();
      table.hostClient.submitDeck(skellige);
      await table.scheduler.flush();
      expect(table.eventsOf<CountdownStarted>(table.guest), isEmpty, reason: 'второй игрок не готов');

      table.guest.submitDeck(northern);
      await table.scheduler.flush();
      expect(table.eventsOf<CountdownStarted>(table.hostClient), [const CountdownStarted(delay)]);
      expect(table.eventsOf<CountdownStarted>(table.guest), [const CountdownStarted(delay)]);

      await table.scheduler.elapse(delay - const Duration(milliseconds: 1));
      expect(table.host.state, isNull);
      await table.scheduler.elapse(const Duration(milliseconds: 1));
      await table.waitFor(() => table.converged, 'партия не началась');
      expect(table.host.state!.phase, MatchPhase.redraw);
    });

    test('отзыв колоды отменяет отсчёт, повторная готовность запускает новый', () async {
      final table = await joined();
      table.hostClient.submitDeck(skellige);
      table.guest.submitDeck(northern);
      await table.scheduler.flush();
      await table.scheduler.elapse(const Duration(seconds: 2));

      table.guest.withdrawDeck();
      await table.scheduler.flush();
      expect(table.eventsOf<CountdownCancelled>(table.hostClient), [const CountdownCancelled()]);
      expect(table.eventsOf<CountdownCancelled>(table.guest), [const CountdownCancelled()]);
      expect(
        table.eventsOf<OpponentLobbyChanged>(table.hostClient).last,
        OpponentLobbyChanged(LobbyStage.chosen, leader: northern.leader),
      );
      await table.scheduler.elapse(const Duration(seconds: 10));
      expect(table.host.state, isNull, reason: 'прерванный отсчёт партию не начинает');

      table.guest.submitDeck(northern);
      await table.scheduler.flush();
      expect(table.eventsOf<CountdownStarted>(table.guest), hasLength(2));
      await table.waitFor(() => table.converged, 'партия не началась');
    });

    test('смена состояния лобби отменяет готовность и отсчёт', () async {
      final table = await joined();
      table.hostClient.submitDeck(skellige);
      table.guest.submitDeck(northern);
      await table.scheduler.flush();

      table.hostClient.reportLobbyStatus(LobbyStage.building);
      await table.scheduler.flush();
      expect(table.eventsOf<CountdownCancelled>(table.guest), hasLength(1));
      await table.scheduler.elapse(const Duration(seconds: 10));
      expect(table.host.state, isNull);
    });

    test('обрыв связи гостя прерывает отсчёт, возвращение запускает его снова', () async {
      final table = await joined();
      table.hostClient.submitDeck(skellige);
      table.guest.submitDeck(northern);
      await table.scheduler.flush();

      await table.guestLink!.cut();
      await table.scheduler.flush();
      expect(table.eventsOf<CountdownCancelled>(table.hostClient), hasLength(1));
      await table.scheduler.elapse(const Duration(seconds: 10));
      expect(table.host.state, isNull);

      table.connectGuest();
      await table.waitFor(() => table.converged, 'после возвращения партия не началась');
    });

    test('без задержки партия начинается сразу, как раньше', () async {
      final table = Table();
      await table.start(skellige, northern);
      expect(table.eventsOf<CountdownStarted>(table.guest), isEmpty);
    });
  });

  group('уход и закрытие', () {
    test('гость ушёл: место свободно сразу, хост видит это, новый гость занимает место', () async {
      final table = await joined();
      table.hostClient.submitDeck(skellige);
      table.guest.submitDeck(northern);
      await table.scheduler.flush();

      table.guest.leaveLobby();
      await table.guest.close();
      await table.scheduler.flush();
      expect(table.eventsOf<OpponentLeft>(table.hostClient), [const OpponentLeft()]);
      expect(table.eventsOf<CountdownCancelled>(table.hostClient), hasLength(1));

      final next = table.newClient('Следующий');
      table.connectGuest(next);
      await table.scheduler.flush();
      expect(next.seat, Seat.two);
      expect(
        table.eventsOf<OpponentLobbyChanged>(next).single,
        OpponentLobbyChanged(LobbyStage.ready, leader: skellige.leader),
      );
      expect(
        table.eventsOf<OpponentLobbyChanged>(table.hostClient).last,
        const OpponentLobbyChanged(LobbyStage.choosing),
      );
    });

    test('хост закрыл лобби: гость узнаёт об этом и не считает это обрывом', () async {
      final table = await joined();
      await table.host.close();
      await table.scheduler.flush();
      expect(table.eventsOf<LobbyClosed>(table.guest), [const LobbyClosed()]);
      expect(table.eventsOf<ConnectionLost>(table.guest), isEmpty);
      expect(table.guest.status, ConnectionStatus.closed);
    });

    test('игрок не вернулся за 120 с: место освобождается, соперник узнаёт об уходе', () async {
      final table = await joined();
      await table.guestLink!.cut();
      await table.scheduler.flush();
      await table.scheduler.elapse(const Duration(minutes: 2, seconds: 1));
      expect(table.eventsOf<OpponentLeft>(table.hostClient), [const OpponentLeft()]);
    });

    test('после начала партии лобби-сообщения отклоняются', () async {
      final table = Table();
      await table.start(skellige, northern);
      final seq = table.guest.reportLobbyStatus(LobbyStage.building);
      final withdraw = table.guest.withdrawDeck();
      await table.scheduler.flush();
      final refusals = table.eventsOf<ActionRefused>(table.guest).map((event) => event.refusal).toList();
      expect(refusals, [
        Refusal(RefusalCode.matchStarted, replyTo: seq),
        Refusal(RefusalCode.matchStarted, replyTo: withdraw),
      ]);
    });
  });

  test('сообщения лобби круглые в кодеке', () {
    const codec = EnvelopeCodec();
    for (final message in <NetMessage>[
      const LobbyStatus(LobbyStage.building),
      const LobbyStatus(LobbyStage.chosen, leader: LeaderId('crach')),
      const DeckWithdrawal(),
      const LobbyLeave(),
      const OpponentLobby(LobbyStage.choosing),
      const OpponentLobby(LobbyStage.ready, leader: LeaderId('crach')),
      const CountdownStart(Duration(seconds: 3)),
      const CountdownCancel(),
      const OpponentLeave(),
      const LobbyClose(),
    ]) {
      final envelope = Envelope(message, seq: message is ControlMessage ? 0 : 5, ack: 2);
      expect(codec.decode(codec.encode(envelope)), envelope);
    }
  });
}
