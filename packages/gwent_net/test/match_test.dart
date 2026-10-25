import 'dart:convert';

import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/table.dart';

/// Партии через хост и два клиента на транспорте в памяти (раздел 8, пункт 2 сетевой спецификации).
void main() {
  group('подключение', () {
    test('места выдаются по порядку, соперники видят друг друга на связи', () async {
      final table = Table()..connectHost();
      await table.scheduler.flush();
      expect(table.hostClient.seat, Seat.one);
      expect(table.eventsOf<OpponentPresenceChanged>(table.hostClient), isEmpty);

      table.connectGuest();
      await table.scheduler.flush();
      expect(table.guest.seat, Seat.two);
      expect(table.guest.status, ConnectionStatus.online);
      expect(table.guest.ticket, ResumeTicket(matchId: table.host.matchId, token: 'token-2'));
      expect(table.eventsOf<OpponentPresenceChanged>(table.hostClient), [
        const OpponentPresenceChanged(online: true, name: 'Гость'),
      ]);
      expect(table.eventsOf<OpponentPresenceChanged>(table.guest), [
        const OpponentPresenceChanged(online: true, name: 'Хост'),
      ]);
    });

    test('третий игрок не помещается', () async {
      final table = Table()
        ..connectHost()
        ..connectGuest();
      final third = table.newClient('Третий');
      table.connectGuest(third);
      await table.scheduler.flush();
      expect(table.eventsOf<JoinRefused>(third), [
        const JoinRefused(JoinRefusal.matchFull, hostProtocol: protocolVersion),
      ]);
      expect(third.status, ConnectionStatus.refused);
      expect(table.guest.status, ConnectionStatus.online, reason: 'место гостя не тронуто');
    });

    test('другой набор правил или версия движка не пускаются', () async {
      for (final other in [
        const Ruleset(id: 'test-pack', hash: 'sha256:other', engineVersion: engineVersion),
        const Ruleset(id: 'other-pack', hash: 'sha256:test', engineVersion: engineVersion),
        const Ruleset(id: 'test-pack', hash: 'sha256:test', engineVersion: engineVersion + 1),
      ]) {
        final table = Table()..connectHost();
        final stranger = table.newClient('Чужой', clientRuleset: other);
        table.connectGuest(stranger);
        await table.scheduler.flush();
        expect(table.eventsOf<JoinRefused>(stranger), [
          const JoinRefused(JoinRefusal.rulesetMismatch, hostProtocol: protocolVersion),
        ]);
      }
    });

    test('клиент другой версии протокола получает понятный отказ', () async {
      final table = Table();
      final (client, server) = InMemoryTransport.pair();
      table.host.accept(server);
      final frames = <Object?>[];
      client.incoming.listen((frame) => frames.add(jsonDecode(utf8.decode(frame))));
      client.send(utf8.encode(jsonEncode({'v': 99, 't': 'hello', 'seq': 0, 'ack': 0, 'p': <String, Object?>{}})));
      await table.scheduler.flush();
      expect(frames, [
        {
          'v': protocolVersion,
          't': 'reject',
          'seq': 0,
          'ack': 0,
          'p': {'reason': 'protocol_mismatch', 'protocol': protocolVersion},
        },
      ]);
    });

    test('хост прежней версии отвечает кадром, которого клиент не разбирает: «обновите приложение»', () async {
      final table = Table();
      final (client, server) = InMemoryTransport.pair();
      table.guest.connect(client);
      server.send(
        utf8.encode(
          jsonEncode({'v': protocolVersion - 1, 't': 'welcome', 'seq': 0, 'ack': 0, 'p': <String, Object?>{}}),
        ),
      );
      await table.scheduler.flush();
      expect(table.eventsOf<JoinRefused>(table.guest), [
        const JoinRefused(JoinRefusal.protocolMismatch, hostProtocol: protocolVersion - 1),
      ]);
      expect(table.guest.status, ConnectionStatus.refused);
    });

    test('чужой токен не возвращает в партию', () async {
      final table = Table()..connectHost();
      final impostor = table.newClient(
        'Самозванец',
        ticket: ResumeTicket(matchId: table.host.matchId, token: 'x'),
      );
      table.connectGuest(impostor);
      await table.scheduler.flush();
      expect(table.eventsOf<JoinRefused>(impostor).single.reason, JoinRefusal.unknownResumeToken);
    });

    test('соединение без hello закрывается', () async {
      final table = Table();
      final (client, server) = InMemoryTransport.pair();
      table.host.accept(server);
      var closed = false;
      client.incoming.listen(null, onDone: () => closed = true);
      client.send(const EnvelopeCodec().encode(const Envelope(Ping(sent: 0))));
      await table.scheduler.flush();
      expect(closed, isTrue);
    });
  });

  group('подготовка', () {
    test('неверная колода отклоняется с нарушениями, партия не начинается', () async {
      final table = Table()
        ..connectHost()
        ..connectGuest();
      final bad = Deck(leader: skellige.leader, cards: [...skellige.cards, const CardId('blue_stripes')]);
      final seq = table.hostClient.submitDeck(bad);
      table.guest.submitDeck(northern);
      await table.scheduler.flush();
      final refusal = table.eventsOf<ActionRefused>(table.hostClient).single.refusal;
      expect(refusal.code, RefusalCode.deckRejected);
      expect(refusal.replyTo, seq);
      expect(refusal.reject!.deckViolations, [const WrongFaction(CardId('blue_stripes'))]);
      expect(table.host.state, isNull);

      table.hostClient.submitDeck(skellige);
      await table.scheduler.flush();
      expect(table.converged, isTrue);
    });

    test('намерение до начала партии и колода после начала отклоняются', () async {
      final table = Table()
        ..connectHost()
        ..connectGuest();
      final early = table.guest.send(const Pass());
      await table.scheduler.flush();
      expect(
        table.eventsOf<ActionRefused>(table.guest).single.refusal,
        Refusal(RefusalCode.matchNotStarted, replyTo: early),
      );

      table.hostClient.submitDeck(skellige);
      table.guest.submitDeck(northern);
      await table.scheduler.flush();
      final late = table.guest.submitDeck(northern);
      await table.scheduler.flush();
      expect(table.eventsOf<ActionRefused>(table.guest).last.refusal, Refusal(RefusalCode.matchStarted, replyTo: late));
    });

    test('колоду можно отправить до welcome: она уйдёт после него', () async {
      final table = Table()..connectHost();
      table.guest.submitDeck(northern);
      table.hostClient.submitDeck(skellige);
      table.connectGuest();
      await table.waitFor(() => table.converged, 'партия не началась');
      expect(table.host.state!.phase, MatchPhase.redraw);
    });
  });

  group('партия', () {
    test('гость ходит только за себя: место берётся из соединения', () async {
      final table = Table();
      await table.start(skellige, northern);
      final finish = table.guest.send(const FinishRedraw());
      await table.waitFor(() => table.converged && table.host.state!.player(Seat.two).redrawDone, 'пересдача гостя');
      expect(table.host.state!.player(Seat.one).redrawDone, isFalse);
      expect(table.eventsOf<ActionRefused>(table.guest).where((event) => event.refusal.replyTo == finish), isEmpty);

      table.hostClient.send(const FinishRedraw());
      await table.waitFor(() => table.host.state!.phase == MatchPhase.playing && table.converged, 'начало раунда');
      final idle = table.host.state!.turn!.opponent;
      final client = idle == Seat.one ? table.hostClient : table.guest;
      final seq = client.send(const Pass());
      await table.scheduler.flush();
      expect(
        table.eventsOf<ActionRefused>(client).last.refusal,
        Refusal(RefusalCode.intentRejected, replyTo: seq, reject: const Reject(RejectReason.notYourTurn)),
      );
    });

    for (final (index, (hostDeck, guestDeck)) in pairings.indexed) {
      test(
        'партия ${hostDeck.leader.value} против ${guestDeck.leader.value} доигрывается, журнал её повторяет',
        () async {
          final table = Table(seed: index + 1);
          await table.start(hostDeck, guestDeck);
          await table.playOut();

          final state = table.host.state!;
          expect(state.outcome, isNotNull);
          for (final client in [table.hostClient, table.guest]) {
            expect(client.view!.outcome, state.outcome);
            expect(table.eventsOf<ViewChanged>(client).last.events.whereType<MatchEnded>(), hasLength(1));
          }

          final record = table.journal.record!;
          expect(record.replay(engine), state, reason: 'журнал воспроизводит партию');
          expect(decodeMatchRecord(jsonDecode(jsonEncode(encodeMatchRecord(record)))), record);
        },
      );
    }

    test('сдача заканчивает партию победой соперника', () async {
      final table = Table();
      await table.start(skellige, northern);
      table.guest.send(const Resign());
      await table.waitFor(() => table.converged && table.host.state!.phase == MatchPhase.finished, 'сдача');
      expect(table.hostClient.view!.outcome, const MatchOutcome(winner: Seat.one, reason: MatchEndReason.resignation));
    });
  });
}
