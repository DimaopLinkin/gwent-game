import 'dart:async';

import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/codec/protocol_exception.dart';
import 'package:gwent_net/src/entropy/entropy.dart';
import 'package:gwent_net/src/host/host_settings.dart';
import 'package:gwent_net/src/host/seat_session.dart';
import 'package:gwent_net/src/journal/match_journal.dart';
import 'package:gwent_net/src/journal/match_record.dart';
import 'package:gwent_net/src/protocol/envelope.dart';
import 'package:gwent_net/src/protocol/net_message.dart';
import 'package:gwent_net/src/protocol/protocol_version.dart';
import 'package:gwent_net/src/session/peer_link.dart';
import 'package:gwent_net/src/session/sequenced_channel.dart';
import 'package:gwent_net/src/time/scheduler.dart';
import 'package:gwent_net/src/transport/transport.dart';

/// Авторитетная сторона партии: телефон, создавший партию, позже сервер (раздел 2 сетевой спецификации).
///
/// Принимает соединения, выдаёт места, проверяет намерения движком и рассылает каждому игроку его события
/// и проекцию. Клиент самого хоста подключается сюда же через `InMemoryTransport`, по тем же правилам.
///
/// Пока один игрок отключён, партия на паузе: намерения соперника, кроме сдачи, отклоняются. Если игрок
/// не вернулся за `reconnectGrace`, он сдаётся; в лобби его место освобождается.
final class MatchHost {
  MatchHost({
    required MatchEngine engine,
    required HostSettings settings,
    required Scheduler scheduler,
    required Entropy entropy,
    MatchJournal? journal,
  }) : _engine = engine,
       _settings = settings,
       _scheduler = scheduler,
       _entropy = entropy,
       _journal = journal ?? InMemoryMatchJournal(),
       matchId = entropy.token();

  final MatchEngine _engine;
  final HostSettings _settings;
  final Scheduler _scheduler;
  final Entropy _entropy;
  final MatchJournal _journal;

  /// Идентификатор партии: гость передаёт его при переподключении вместе с токеном.
  final String matchId;

  final Map<Seat, SeatSession> _seats = {};

  /// Соединения, которые ещё не прислали `hello`.
  final Set<PeerLink> _anonymous = {};
  MatchState? _state;
  bool _closed = false;

  /// Полное состояние партии; `null` до начала. Его видит только хост, игрокам уходят проекции.
  MatchState? get state => _state;

  /// Новое входящее соединение. Первым сообщением в нём должен быть `hello`.
  void accept(Transport transport) {
    if (_closed) {
      unawaited(transport.close());
      return;
    }
    _anonymous.add(
      PeerLink(
        transport,
        scheduler: _scheduler,
        timeout: _settings.linkTimeout,
        onEnvelope: _onEnvelope,
        onMalformed: _onMalformed,
        onLost: _onLost,
      ),
    );
  }

  /// Закрывает все соединения и таймеры. Партия дальше не идёт.
  Future<void> close() async {
    _closed = true;
    final links = [..._anonymous, for (final session in _seats.values) ?session.link];
    _anonymous.clear();
    for (final session in _seats.values) {
      session.grace?.cancel();
      session.link = null;
    }
    await Future.wait(links.map((link) => link.close()));
  }

  void _onEnvelope(PeerLink link, Envelope envelope) {
    final session = _sessionOf(link);
    if (session == null) {
      if (envelope.message case final Hello hello) {
        _onHello(link, envelope, hello);
      } else {
        unawaited(link.close());
      }
      return;
    }
    session.confirmed = true;
    final channel = session.channel;
    switch (channel.receive(envelope)) {
      case Delivery.control:
        _onControl(session, link, envelope.message);
      case Delivery.next:
        _onSequenced(session, envelope);
      case Delivery.gap:
        if (channel.claimResendRequest()) link.send(channel.control(const ResendRequest()));
      case Delivery.duplicate:
        break;
    }
  }

  void _onMalformed(PeerLink link, ProtocolException error) {
    if (error is UnsupportedProtocol && _anonymous.contains(link)) {
      _reject(link, JoinRefusal.protocolMismatch);
    } else {
      unawaited(link.close());
    }
  }

  void _onLost(PeerLink link) {
    if (_anonymous.remove(link) || _closed) return;
    final session = _sessionOf(link);
    if (session == null) return;
    session.link = null;
    if (_state?.phase == MatchPhase.finished) return;
    _announce(session.seat);
    session.grace = _scheduler.timer(_settings.reconnectGrace, () => _expire(session));
  }

  void _onHello(PeerLink link, Envelope envelope, Hello hello) {
    if (hello.ruleset != _settings.ruleset) return _reject(link, JoinRefusal.rulesetMismatch);
    final token = hello.resumeToken;
    if (token != null) {
      final session = _seats.values.where((session) => session.token == token).firstOrNull;
      if (session == null || envelope.matchId != matchId) return _reject(link, JoinRefusal.unknownResumeToken);
      return _resume(session, link, envelope.ack);
    }
    final seat = _freeSeat();
    if (seat == null) return _reject(link, JoinRefusal.matchFull);
    _seats[seat]?.grace?.cancel();
    final session = SeatSession(seat: seat, token: _entropy.token(), playerName: hello.playerName, matchId: matchId);
    _seats[seat] = session;
    _bind(session, link);
    link.send(session.channel.control(Welcome(seat: seat, matchId: matchId, resumeToken: session.token, next: 1)));
    _announce(seat);
    _announce(seat.opponent);
  }

  /// Место для нового игрока: свободное или занятое клиентом, который так и не получил `welcome`.
  Seat? _freeSeat() {
    if (_state != null) return null;
    for (final seat in Seat.values) {
      if (!_seats.containsKey(seat)) return seat;
    }
    for (final seat in Seat.values) {
      final session = _seats[seat]!;
      if (!session.online && !session.confirmed) return seat;
    }
    return null;
  }

  /// Возвращает игрока на его место: досылает пропущенное или, если его уже нет, отдаёт снимок.
  void _resume(SeatSession session, PeerLink link, int peerAck) {
    _bind(session, link);
    final channel = session.channel..acknowledge(peerAck);
    final resumable = channel.canResumeFrom(peerAck);
    if (!resumable) channel.discardUnacked();
    final next = resumable ? peerAck + 1 : channel.sent + 1;
    link.send(
      channel.control(Welcome(seat: session.seat, matchId: matchId, resumeToken: session.token, next: next)),
    );
    if (resumable) {
      channel.pending().forEach(link.send);
    } else if (_state case final state?) {
      _send(session, MatchSnapshot(_engine.project(state, session.seat)));
    }
    _announce(session.seat);
    _announce(session.seat.opponent);
  }

  void _bind(SeatSession session, PeerLink link) {
    _anonymous.remove(link);
    final previous = session.link;
    session
      ..link = link
      ..grace?.cancel()
      ..grace = null;
    // Старое соединение могло ещё не заметить обрыв (полуоткрытый сокет): закрываем его, его onLost
    // увидит, что место уже занято новым соединением.
    if (previous != null && previous != link) unawaited(previous.close());
  }

  void _reject(PeerLink link, JoinRefusal reason) {
    _anonymous.remove(link);
    link.send(Envelope(JoinRejected(reason, protocol: protocolVersion)));
    unawaited(link.close());
  }

  void _onControl(SeatSession session, PeerLink link, NetMessage message) {
    final channel = session.channel;
    switch (message) {
      case Ping(:final sent):
        link.send(channel.control(Pong(sent: channel.sent)));
        if (sent > channel.received) link.send(channel.control(const ResendRequest()));
      case ResendRequest():
        channel.pending().forEach(link.send);
      case Hello() || Welcome() || JoinRejected() || Pong() || ClientMessage() || HostMessage():
        // Клиент такое не шлёт после `welcome`; номерные сообщения сюда не попадают.
        break;
    }
  }

  void _onSequenced(SeatSession session, Envelope envelope) {
    switch (envelope.message) {
      case DeckSubmission(:final deck):
        _onDeck(session, deck, envelope.seq);
      case IntentMessage(:final intent):
        _onIntent(session, intent, envelope.seq);
      case ControlMessage() || HostMessage():
        // Нарушение протокола: сообщение хоста от клиента.
        unawaited(session.link?.close());
    }
  }

  void _onDeck(SeatSession session, Deck deck, int seq) {
    if (_state != null) return _refuse(session, RefusalCode.matchStarted, seq);
    final violations = _engine.validateDeck(deck);
    if (violations.isNotEmpty) {
      final reject = Reject(
        RejectReason.invalidDeck,
        seat: session.seat,
        deckViolations: List.unmodifiable(violations),
      );
      return _refuse(session, RefusalCode.deckRejected, seq, reject);
    }
    session.deck = deck;
    _startIfReady();
  }

  void _startIfReady() {
    final one = _seats[Seat.one]?.deck;
    final two = _seats[Seat.two]?.deck;
    if (one == null || two == null) return;
    final record = MatchRecord(matchId: matchId, ruleset: _settings.ruleset, seed: _entropy.seed(), one: one, two: two);
    switch (_engine.start(record.setup)) {
      case Accepted(:final state, :final events):
        _state = state;
        _journal.begin(record);
        _broadcast(state, events);
      case Rejected(:final reject):
        // Колоды уже проверены той же функцией движка по одной; сюда попасть нельзя.
        throw StateError('Движок не начал партию с проверенными колодами: $reject');
    }
  }

  void _onIntent(SeatSession session, Intent intent, int seq) {
    if (_state == null) return _refuse(session, RefusalCode.matchNotStarted, seq);
    final opponentOnline = _seats[session.seat.opponent]?.online ?? false;
    if (intent is! Resign && !opponentOnline) return _refuse(session, RefusalCode.matchPaused, seq);
    _apply(session.seat, intent, replyTo: seq);
  }

  void _apply(Seat seat, Intent intent, {int? replyTo}) {
    switch (_engine.apply(_state!, seat, intent)) {
      case Rejected(:final reject):
        if (replyTo != null) _refuse(_seats[seat]!, RefusalCode.intentRejected, replyTo, reject);
      case Accepted(:final state, :final events):
        _state = state;
        _journal.append(RecordedMove(seat, intent));
        _broadcast(state, events);
        if (state.phase == MatchPhase.finished) {
          for (final session in _seats.values) {
            session.grace?.cancel();
            session.grace = null;
          }
        }
    }
  }

  /// Игрок не вернулся вовремя: в партии он сдаётся, в лобби освобождает место.
  void _expire(SeatSession session) {
    session.grace = null;
    if (session.online || _seats[session.seat] != session) return;
    if (_state == null) {
      _seats.remove(session.seat);
    } else {
      _apply(session.seat, const Resign());
    }
  }

  void _broadcast(MatchState state, List<GameEvent> events) {
    for (final session in _seats.values) {
      final seat = session.seat;
      _send(session, MatchUpdate(_engine.eventsFor(events, seat), _engine.project(state, seat)));
    }
  }

  /// Говорит сопернику игрока [about], на связи ли тот.
  void _announce(Seat about) {
    final subject = _seats[about];
    final target = _seats[about.opponent];
    if (subject != null && target != null) {
      _send(target, OpponentPresence(online: subject.online, name: subject.playerName));
    }
  }

  void _refuse(SeatSession session, RefusalCode code, int replyTo, [Reject? reject]) =>
      _send(session, Refusal(code, replyTo: replyTo, reject: reject));

  /// Отправляет сообщение с номером; если игрок отключён, оно дождётся переподключения.
  void _send(SeatSession session, HostMessage message) {
    final envelope = session.channel.sequenced(message);
    session.link?.send(envelope);
  }

  SeatSession? _sessionOf(PeerLink link) => _seats.values.where((session) => session.link == link).firstOrNull;
}
