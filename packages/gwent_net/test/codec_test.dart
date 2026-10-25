import 'dart:convert';
import 'dart:typed_data';

import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  const codec = EnvelopeCodec();
  const a = CardInstance(CardInstanceId(7), CardId('geralt'));
  const b = CardInstance(CardInstanceId(12), CardId('frost'));

  Envelope roundTrip(Envelope envelope) => codec.decode(codec.encode(envelope));

  Uint8List frame(Map<String, Object?> json) => utf8.encode(jsonEncode(json));

  group('кадр', () {
    test('эталонный кадр намерения: имена полей и значений закреплены', () {
      final bytes = codec.encode(
        const Envelope(IntentMessage(PlayCard(CardInstanceId(42), row: Row.melee)), seq: 3, ack: 2, matchId: 'm1'),
      );
      expect(
        utf8.decode(bytes),
        '{"v":2,"t":"intent","seq":3,"ack":2,"m":"m1","p":{"intent":{"type":"play_card","card":42,"row":"melee"}}}',
      );
    });

    test('эталонный кадр отказа: значения перечислений в snake_case', () {
      final bytes = codec.encode(
        const Envelope(
          Refusal(RefusalCode.intentRejected, replyTo: 4, reject: Reject(RejectReason.notYourTurn)),
          seq: 7,
          ack: 4,
        ),
      );
      expect(
        utf8.decode(bytes),
        '{"v":2,"t":"error","seq":7,"ack":4,"p":{"code":"intent_rejected","reply_to":4,'
        '"reject":{"reason":"not_your_turn","violations":[]}}}',
      );
    });

    test('все намерения проходят туда и обратно', () {
      const intents = <Intent>[
        RedrawCard(CardInstanceId(3)),
        FinishRedraw(),
        PlayCard(CardInstanceId(4)),
        PlayCard(CardInstanceId(4), row: Row.siege, target: CardInstanceId(9)),
        UseLeader(),
        Pass(),
        ChooseOption(CardOption(a)),
        ChooseOption(RowOption(Row.ranged)),
        ChooseOption(SeatOption(Seat.two)),
        Resign(),
      ];
      for (final intent in intents) {
        final envelope = Envelope(IntentMessage(intent), seq: 1);
        expect(roundTrip(envelope), envelope);
      }
    });

    test('все события проходят туда и обратно', () {
      const events = <GameEvent>[
        FirstPlayerChosen(Seat.two, byChoice: true),
        DeckShuffled(Seat.one),
        CardsDrawn(Seat.one, [a, b]),
        CardsDrawnHidden(Seat.two, 2),
        CardRedrawn(Seat.one, returned: a, drawn: b),
        RedrawFinished(Seat.two),
        RoundStarted(2, Seat.one),
        TurnStarted(Seat.two),
        CardPlayed(Seat.one, a),
        UnitPlaced(Seat.two, Row.ranged, a, EntrySource.musterFromDeck),
        CreatedCardPlaced(Seat.one, Row.melee, a),
        BerserkTransformed(Seat.one, Row.melee, berserk: a, into: b),
        SlotFilled(Seat.one, Row.siege, CardSlot(b)),
        SlotFilled(Seat.two, Row.melee, LeaderHornSlot()),
        WeatherPlayed(Seat.two, b),
        WeatherCleared(),
        UnitDecoyed(Seat.one, Row.melee, decoy: b, returned: a),
        UnitsDestroyed([DestroyedUnit(Seat.one, Row.melee, a), DestroyedUnit(Seat.two, Row.siege, b)]),
        CardDiscarded(Seat.two, a),
        CardLeftGame(b),
        CardTakenFromDiscard(Seat.one, Seat.two, a),
        DiscardShuffledIntoDeck(Seat.one),
        LeaderUsed(Seat.two, LeaderId('crach')),
        HandRevealed(Seat.one, [a]),
        Passed(Seat.two, auto: true),
        ChoiceRequested(Seat.one, ChoiceKind.medicTarget, [CardOption(a), RowOption(Row.ranged), SeatOption(Seat.two)]),
        ChoiceRequested(Seat.two, ChoiceKind.firstPlayer, []),
        UnitKept(Seat.two, Row.ranged, a),
        RoundEnded(RoundResult(round: 1, scores: {Seat.one: 10, Seat.two: 12}, winner: Seat.two)),
        RoundEnded(RoundResult(round: 2, scores: {Seat.one: 5, Seat.two: 5}, winner: null)),
        MatchEnded(MatchOutcome(winner: null, reason: MatchEndReason.crystals)),
        MatchEnded(MatchOutcome(winner: Seat.one, reason: MatchEndReason.resignation)),
        UnitMoved(Seat.one, a, from: Row.melee, to: Row.ranged),
      ];
      final view = engine.project(_started(), Seat.one);
      for (final event in events) {
        final envelope = Envelope(MatchUpdate([event], view), seq: 5, ack: 1, matchId: 'm');
        expect(roundTrip(envelope), envelope, reason: '$event');
      }
    });

    test('проекции партии проходят туда и обратно на каждом этапе', () {
      var state = _started();
      final views = <PlayerView>[];
      for (final intent in const [FinishRedraw(), FinishRedraw()]) {
        views.addAll(Seat.values.map((seat) => engine.project(state, seat)));
        state = (engine.apply(state, views.length == 2 ? Seat.one : Seat.two, intent) as Accepted).state;
      }
      views.add(engine.project(state, state.turn!));
      // Проекция с выбором, слотом рога, погодой и историей.
      views.add(
        PlayerView(
          viewer: Seat.two,
          phase: MatchPhase.playing,
          round: 3,
          roundStarter: Seat.one,
          turn: Seat.two,
          me: views.last.me,
          opponent: views.last.opponent,
          weather: const [WeatherCard(b, Seat.one)],
          choice: const PendingChoice(
            seat: Seat.two,
            kind: ChoiceKind.unitRow,
            options: [RowOption(Row.melee)],
            subject: a,
          ),
          opponentChoosing: ChoiceKind.deckCard,
          history: const [
            RoundResult(round: 1, scores: {Seat.one: 1, Seat.two: 2}, winner: Seat.two),
          ],
          outcome: const MatchOutcome(winner: Seat.two, reason: MatchEndReason.crystals),
        ),
      );
      for (final view in views) {
        final envelope = Envelope(MatchSnapshot(view), seq: 2);
        expect(roundTrip(envelope), envelope);
      }
    });

    test('все служебные сообщения, колода и отказы проходят туда и обратно', () {
      const violations = <DeckViolation>[
        UnknownLeader(LeaderId('x')),
        LeaderNotDeckFaction(LeaderId('y')),
        UnknownCard(CardId('z')),
        WrongFaction(CardId('blue_stripes')),
        CreatedCardInDeck(CardId('bovine')),
        TooManyCopies(CardId('geralt'), count: 2, max: 1),
        TooFewUnitCards(count: 10, min: 22),
        TooManySpecialCards(count: 11, max: 10),
      ];
      final envelopes = [
        const Envelope(Hello(ruleset: ruleset, playerName: 'Геральт', appVersion: '1.0.0')),
        const Envelope(Hello(ruleset: ruleset, playerName: 'Цири', appVersion: '1.0.0', resumeToken: 't'), ack: 4),
        const Envelope(
          Welcome(seat: Seat.two, matchId: 'm', resumeToken: 't', next: 5),
          ack: 2,
          matchId: 'm',
        ),
        const Envelope(JoinRejected(JoinRefusal.matchFull, protocol: protocolVersion)),
        const Envelope(Ping(sent: 3), ack: 2, matchId: 'm'),
        const Envelope(Pong(sent: 4), ack: 3, matchId: 'm'),
        const Envelope(ResendRequest(), ack: 7, matchId: 'm'),
        Envelope(DeckSubmission(skellige), seq: 1),
        const Envelope(OpponentPresence(online: false, name: 'Цири'), seq: 8),
        const Envelope(OpponentPresence(online: true, name: 'Цири', unstable: true, away: true), seq: 8),
        const Envelope(Refusal(RefusalCode.matchPaused, replyTo: 3), seq: 9),
        const Envelope(
          Refusal(
            RefusalCode.deckRejected,
            replyTo: 1,
            reject: Reject(RejectReason.invalidDeck, seat: Seat.one, deckViolations: violations),
          ),
          seq: 10,
        ),
      ];
      for (final envelope in envelopes) {
        expect(roundTrip(envelope), envelope);
      }
    });

    test('журнал партии проходит туда и обратно', () {
      final record = MatchRecord(
        matchId: 'm',
        ruleset: ruleset,
        seed: 1 << 40,
        one: skellige,
        two: northern,
        moves: const [RecordedMove(Seat.one, FinishRedraw()), RecordedMove(Seat.two, PlayCard(CardInstanceId(3)))],
      );
      expect(decodeMatchRecord(jsonDecode(jsonEncode(encodeMatchRecord(record)))), record);
    });
  });

  group('ошибки разбора', () {
    Matcher malformed(String fragment) =>
        throwsA(isA<MalformedFrame>().having((error) => error.message, 'message', contains(fragment)));

    test('не JSON, не объект, неизвестный тип', () {
      expect(() => codec.decode(utf8.encode('{')), malformed('не JSON'));
      expect(() => codec.decode(utf8.encode('[]')), malformed(r'$: ожидался объект'));
      expect(() => codec.decode(frame({'v': 2, 't': 'dance', 'seq': 0, 'ack': 0, 'p': {}})), malformed('dance'));
    });

    test('поле не того типа называется по пути', () {
      final json = {
        'v': 2,
        't': 'intent',
        'seq': 1,
        'ack': 0,
        'p': {
          'intent': {'type': 'play_card', 'card': 'семь'},
        },
      };
      expect(() => codec.decode(frame(json)), malformed(r'$.p.intent.card: ожидалось: целое число'));
    });

    test('номер должен быть у номерных сообщений и только у них', () {
      expect(
        () => codec.decode(frame({'v': 2, 't': 'resend', 'seq': 4, 'ack': 0, 'p': <String, Object?>{}})),
        malformed('номер 4'),
      );
      expect(
        () => codec.decode(
          frame({
            'v': 2,
            't': 'opponent',
            'seq': 0,
            'ack': 0,
            'p': {'online': true, 'name': 'Цири'},
          }),
        ),
        malformed('нет номера'),
      );
      expect(
        () => codec.decode(frame({'v': 2, 't': 'resend', 'seq': 0, 'ack': -1, 'p': <String, Object?>{}})),
        malformed('отрицательный'),
      );
    });

    test('другая версия протокола: отдельная ошибка, а reject понятен любой версии', () {
      expect(
        () => codec.decode(frame({'v': 3, 't': 'hello', 'seq': 0, 'ack': 0, 'p': <String, Object?>{}})),
        throwsA(isA<UnsupportedProtocol>().having((error) => error.version, 'version', 3)),
      );
      expect(
        () => codec.decode(frame({'v': 3, 'type': 'hello'})),
        throwsA(isA<UnsupportedProtocol>()),
        reason: 'кадр будущей версии без поля t',
      );
      final reject = codec.decode(
        frame({
          'v': 3,
          't': 'reject',
          'seq': 0,
          'ack': 0,
          'p': {'reason': 'protocol_mismatch', 'protocol': 3},
        }),
      );
      expect(reject.message, const JoinRejected(JoinRefusal.protocolMismatch, protocol: 3));
    });

    test('слишком большой кадр не разбирается', () {
      expect(() => const EnvelopeCodec(maxFrameBytes: 10).decode(utf8.encode('{"v":2,"t":"ping"}')), malformed('байт'));
    });
  });
}

MatchState _started() =>
    (engine.start(MatchSetup(one: skellige, two: northern, rng: const SeededRng(5))) as Accepted).state;
