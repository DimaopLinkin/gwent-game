import 'dart:async';

import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/codec/protocol_exception.dart';
import 'package:gwent_net/src/entropy/entropy.dart';
import 'package:gwent_net/src/host/host_settings.dart';
import 'package:gwent_net/src/host/pending_guest.dart';
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

  /// Соединения, принятые как доверенные: клиент самого хоста.
  final Set<PeerLink> _trusted = {};
  final StreamController<PendingGuest?> _pending = StreamController<PendingGuest?>.broadcast();

  /// Соединения, которые ещё не прислали `hello`.
  final Set<PeerLink> _anonymous = {};
  MatchState? _state;
  bool _closed = false;

  /// Отсчёт до старта партии: идёт, пока оба игрока готовы и на связи.
  Timer? _countdown;

  /// Время на ответ о реванше: идёт с первой просьбы, пока соперник не согласился.
  Timer? _rematchTimer;

  /// Время на ответ о реванше вышло.
  bool _rematchExpired = false;

  /// Полное состояние партии; `null` до начала. Его видит только хост, игрокам уходят проекции.
  MatchState? get state => _state;

  /// Игрок, который ждёт решения хоста; `null`, если никого нет.
  PendingGuest? get pendingGuestNow {
    for (final session in _seats.values) {
      if (!session.admitted) return PendingGuest(session.seat, session.playerName);
    }
    return null;
  }

  /// Каждое изменение ожидающего игрока: новый стучащийся или `null`, когда решение принято или игрок ушёл.
  Stream<PendingGuest?> get pendingGuest => _pending.stream;

  /// Хост пускает ожидающего игрока на место [seat]: он и соперник узнают друг о друге.
  void admit(Seat seat) {
    final session = _seats[seat];
    if (session == null || session.admitted || _closed) return;
    session
      ..admitted = true
      ..admission?.cancel();
    session.admission = null;
    if (!_pending.isClosed) _pending.add(null);
    _send(session, const Admitted());
    _announce(seat);
    _announce(seat.opponent);
    _announceLobby(seat);
    _announceLobby(seat.opponent);
  }

  /// Хост не пускает ожидающего игрока: тот получает отказ, место свободно для другого.
  void decline(Seat seat) {
    final session = _seats[seat];
    if (session == null || session.admitted || _closed) return;
    final link = session.link;
    _dropPending(session);
    if (link != null) _reject(link, JoinRefusal.declined);
  }

  /// Убирает ожидающего игрока: место свободно, запрос снят.
  void _dropPending(SeatSession session) {
    session.admission?.cancel();
    session.admission = null;
    session.grace?.cancel();
    session.link = null;
    _seats.remove(session.seat);
    if (!_pending.isClosed) _pending.add(null);
  }

  /// Новое входящее соединение. Первым сообщением в нём должен быть `hello`.
  ///
  /// [trusted] — соединение самого хоста (его клиент): оно не ждёт согласия, даже когда оно требуется от других.
  void accept(Transport transport, {bool trusted = false}) {
    if (_closed) {
      unawaited(transport.close());
      return;
    }
    final link = PeerLink(
      transport,
      scheduler: _scheduler,
      timeout: _settings.linkTimeout,
      onEnvelope: _onEnvelope,
      onMalformed: _onMalformed,
      onLost: _onLost,
      quietAfter: _settings.unstableAfter,
      onQuiet: _onQuiet,
    );
    _anonymous.add(link);
    if (trusted) _trusted.add(link);
  }

  /// Игрок [seat] свернул приложение ([away]) или вернулся: соперник узнаёт об этом, пока связь жива.
  void setAway(Seat seat, {required bool away}) {
    final session = _seats[seat];
    if (session == null || session.away == away) return;
    session.away = away;
    _announce(seat);
  }

  /// Закрывает все соединения и таймеры. Партия дальше не идёт.
  Future<void> close() async {
    if (_closed) return;
    // В лобби игроки узнают, что возвращаться некуда; в партии они переподключатся к новому хосту сами.
    if (_state == null) {
      for (final session in _seats.values) {
        _send(session, const LobbyClose());
      }
    } else if (_state?.phase == MatchPhase.finished) {
      // На экране итога хост уходит: реванша не будет, об этом гость узнаёт сразу, а не по обрыву связи.
      for (final session in _seats.values.where((session) => session.admitted && session.online)) {
        _send(session, RematchStatus(RematchPhase.opponentGone, window: _settings.rematchWindow));
      }
    }
    _closed = true;
    _countdown?.cancel();
    _countdown = null;
    _rematchTimer?.cancel();
    _rematchTimer = null;
    unawaited(_pending.close());
    final links = [..._anonymous, for (final session in _seats.values) ?session.link];
    _anonymous.clear();
    for (final session in _seats.values) {
      session.grace?.cancel();
      session.admission?.cancel();
      session.resendCooldown?.cancel();
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
    _trusted.remove(link);
    if (_anonymous.remove(link) || _closed) return;
    final session = _sessionOf(link);
    if (session == null) return;
    // Ждавший решения игрок ушёл: хост о нём не знал и не ждёт.
    if (!session.admitted) return _dropPending(session);
    session
      ..link = null
      ..unstable = false;
    if (_state?.phase == MatchPhase.finished) return _announceRematch();
    _cancelCountdown();
    _announce(session.seat);
    session.grace = _scheduler.timer(_settings.reconnectGrace, () => _expire(session));
  }

  void _onHello(PeerLink link, Envelope envelope, Hello hello) {
    if (_closed) return;
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
    final session = SeatSession(seat: seat, token: _entropy.token(), playerName: hello.playerName, matchId: matchId)
      ..admitted = !_settings.requireAdmission || _trusted.contains(link);
    _seats[seat] = session;
    _bind(session, link);
    link.send(session.channel.control(Welcome(seat: seat, matchId: matchId, resumeToken: session.token, next: 1)));
    if (!session.admitted) {
      session.admission = _scheduler.timer(_settings.admissionTimeout, () => decline(seat));
      if (!_pending.isClosed) _pending.add(PendingGuest(seat, session.playerName));
      return;
    }
    _send(session, const Admitted());
    _announce(seat);
    _announce(seat.opponent);
    _announceLobby(seat);
    _announceLobby(seat.opponent);
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
      session.rematchShown = null;
    } else {
      // В лобби снимка нет: игрок узнаёт о сопернике из объявлений ниже.
      _announceLobby(session.seat.opponent);
    }
    _announce(session.seat);
    _announce(session.seat.opponent);
    _announceLobby(session.seat);
    if (_state?.phase == MatchPhase.finished) _announceRematch();
    _startIfReady();
  }

  void _onQuiet(PeerLink link, {required bool quiet}) {
    final session = _sessionOf(link);
    if (session == null || session.unstable == quiet) return;
    session.unstable = quiet;
    _announce(session.seat);
  }

  void _bind(SeatSession session, PeerLink link) {
    _anonymous.remove(link);
    final previous = session.link;
    session
      ..link = link
      ..unstable = false
      ..grace?.cancel()
      ..grace = null;
    // Старое соединение могло ещё не заметить обрыв (полуоткрытый сокет): закрываем его, его onLost
    // увидит, что место уже занято новым соединением.
    if (previous != null && previous != link) unawaited(previous.close());
  }

  void _reject(PeerLink link, JoinRefusal reason) {
    _anonymous.remove(link);
    _trusted.remove(link);
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
        // Пауза между ответами: иначе короткая просьба заставляла бы хост снова и снова слать всю очередь.
        if (session.resendCooldown != null) break;
        session.resendCooldown = _scheduler.timer(_settings.resendCooldown, () => session.resendCooldown = null);
        channel.pending().forEach(link.send);
      case Hello() || Welcome() || JoinRejected() || Pong() || ClientMessage() || HostMessage():
        // Клиент такое не шлёт после `welcome`; номерные сообщения сюда не попадают.
        break;
    }
  }

  void _onSequenced(SeatSession session, Envelope envelope) {
    if (!session.admitted) {
      // Хост ещё не решил: уйти игрок может, остальное хост не принимает.
      if (envelope.message is LobbyLeave) {
        final link = session.link;
        _dropPending(session);
        if (link != null) unawaited(link.close());
      }
      return;
    }
    switch (envelope.message) {
      case DeckSubmission(:final deck):
        _onDeck(session, deck, envelope.seq);
      case IntentMessage(:final intent):
        _onIntent(session, intent, envelope.seq);
      case final LobbyStatus status:
        _onLobbyStatus(session, status, envelope.seq);
      case DeckWithdrawal():
        _onWithdrawal(session, envelope.seq);
      case LobbyLeave():
        _onLeave(session);
      case RematchRequest():
        _onRematch(session, envelope.seq);
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
    session
      ..deck = deck
      ..draft = LobbyStatus(LobbyStage.chosen, leader: deck.leader);
    // Другая колода во время отсчёта: прежний отсчёт отменяется, новый идёт заново, соперник успевает увидеть смену.
    _cancelCountdown();
    _announceLobby(session.seat);
    _startIfReady();
  }

  void _onLobbyStatus(SeatSession session, LobbyStatus status, int seq) {
    if (_state != null) return _refuse(session, RefusalCode.matchStarted, seq);
    session
      ..draft = status
      ..deck = null;
    _cancelCountdown();
    _announceLobby(session.seat);
  }

  void _onWithdrawal(SeatSession session, int seq) {
    if (_state != null) return _refuse(session, RefusalCode.matchStarted, seq);
    if (session.deck == null) return;
    session.deck = null;
    _cancelCountdown();
    _announceLobby(session.seat);
  }

  /// Игрок ушёл из лобби: место свободно сразу. Соединение закроет сам игрок, а закрытое хостом место с новым
  /// игроком уже не спутает.
  void _onLeave(SeatSession session) {
    if (_state != null) return;
    _cancelCountdown();
    session.grace?.cancel();
    _seats.remove(session.seat);
    final link = session.link;
    session.link = null;
    if (link != null) unawaited(link.close());
    if (_seats[session.seat.opponent] case final remaining? when remaining.admitted) {
      _send(remaining, const OpponentLeave());
    }
  }

  /// Игрок просит реванш или соглашается на него. Когда согласны оба, партия сбрасывается до лобби.
  void _onRematch(SeatSession session, int seq) {
    if (_state?.phase != MatchPhase.finished) return _refuse(session, RefusalCode.matchNotFinished, seq);
    final other = _seats[session.seat.opponent];
    if (_rematchExpired || session.rematch || other == null || !other.online || !other.admitted) return;
    session.rematch = true;
    if (other.rematch) return _startRematch();
    // Время идёт с первой просьбы: соперник успевает ответить, но не вечно.
    _rematchTimer ??= _scheduler.timer(_settings.rematchWindow, () {
      _rematchTimer = null;
      _rematchExpired = true;
      _announceRematch();
    });
    _announceRematch();
  }

  /// Оба согласны: партия забыта, игроки снова в лобби без колод. Места, токены и соединения остаются прежними.
  void _startRematch() {
    _rematchTimer?.cancel();
    _rematchTimer = null;
    _rematchExpired = false;
    _state = null;
    for (final session in _seats.values) {
      session
        ..rematch = false
        ..rematchShown = null
        ..deck = null
        ..draft = const LobbyStatus(LobbyStage.choosing);
    }
    for (final session in _seats.values.where((session) => session.admitted)) {
      _send(session, const RematchStart());
    }
    _announceLobby(Seat.one);
    _announceLobby(Seat.two);
  }

  /// Фаза реванша для игрока [session]: что он видит на экране итога.
  RematchPhase _rematchPhase(SeatSession session) {
    final other = _seats[session.seat.opponent];
    if (other == null || !other.online) return RematchPhase.opponentGone;
    if (_rematchExpired) return RematchPhase.expired;
    if (session.rematch) return RematchPhase.asked;
    if (other.rematch) return RematchPhase.invited;
    return RematchPhase.idle;
  }

  /// Сообщает каждому игроку, на связи которого хост, как идёт реванш. Повтор прежней фазы не отправляется.
  void _announceRematch() {
    for (final session in _seats.values.where((session) => session.admitted && session.online)) {
      final phase = _rematchPhase(session);
      if (session.rematchShown == phase) continue;
      session.rematchShown = phase;
      _send(session, RematchStatus(phase, window: _settings.rematchWindow));
    }
  }

  void _startIfReady() {
    if (_state != null || _countdown != null) return;
    final one = _seats[Seat.one];
    final two = _seats[Seat.two];
    if (one?.deck == null || two?.deck == null) return;
    final delay = _settings.startDelay;
    if (delay == Duration.zero) return _start();
    // Отсчёт идёт только пока оба на связи: отключившийся игрок может не вернуться.
    if (!one!.online || !two!.online) return;
    for (final session in [one, two]) {
      _send(session, CountdownStart(delay));
    }
    _countdown = _scheduler.timer(delay, () {
      _countdown = null;
      _start();
    });
  }

  void _cancelCountdown() {
    final countdown = _countdown;
    if (countdown == null) return;
    countdown.cancel();
    _countdown = null;
    for (final session in _seats.values.where((session) => session.admitted)) {
      _send(session, const CountdownCancel());
    }
  }

  void _start() {
    final one = _seats[Seat.one]?.deck;
    final two = _seats[Seat.two]?.deck;
    if (_state != null || one == null || two == null) return;
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
            session.rematch = false;
            session.rematchShown = null;
          }
          _rematchExpired = false;
        }
    }
  }

  /// Игрок не вернулся вовремя: в партии он сдаётся, в лобби освобождает место.
  void _expire(SeatSession session) {
    session.grace = null;
    if (session.online || _seats[session.seat] != session) return;
    if (_state == null) {
      _seats.remove(session.seat);
      if (_seats[session.seat.opponent] case final remaining? when remaining.admitted) {
        _send(remaining, const OpponentLeave());
      }
    } else {
      _apply(session.seat, const Resign());
    }
  }

  void _broadcast(MatchState state, List<GameEvent> events) {
    for (final session in _seats.values.where((session) => session.admitted)) {
      final seat = session.seat;
      _send(session, MatchUpdate(_engine.eventsFor(events, seat), _engine.project(state, seat)));
    }
  }

  /// Говорит сопернику игрока [about], на связи ли тот.
  void _announce(Seat about) {
    final subject = _seats[about];
    final target = _seats[about.opponent];
    if (subject != null && target != null && subject.admitted && target.admitted) {
      _send(
        target,
        OpponentPresence(
          online: subject.online,
          name: subject.playerName,
          unstable: subject.online && subject.unstable,
          away: subject.away,
        ),
      );
    }
  }

  /// Говорит сопернику игрока [about], чем тот занят в лобби. После начала партии лобби нет.
  void _announceLobby(Seat about) {
    final subject = _seats[about];
    final target = _seats[about.opponent];
    if (subject == null || target == null || !subject.admitted || !target.admitted || _state != null) return;
    final deck = subject.deck;
    _send(
      target,
      deck == null
          ? OpponentLobby(subject.draft.stage, leader: subject.draft.leader)
          : OpponentLobby(LobbyStage.ready, leader: deck.leader),
    );
  }

  void _refuse(SeatSession session, RefusalCode code, int replyTo, [Reject? reject]) =>
      _send(session, Refusal(code, replyTo: replyTo, reject: reject));

  /// Отправляет сообщение с номером; если игрок отключён, оно дождётся переподключения.
  void _send(SeatSession session, HostMessage message) {
    final channel = session.channel;
    final envelope = channel.sequenced(message);
    if (channel.unackedCount > _settings.maxUnacked) {
      // Игрок не подтверждает сообщения (зависший или враждебный клиент): очередь не растёт дальше, а вернувшийся
      // игрок начнёт со снимка.
      channel.discardUnacked();
      final link = session.link;
      if (link != null) unawaited(link.close());
      return;
    }
    session.link?.send(envelope);
  }

  SeatSession? _sessionOf(PeerLink link) => _seats.values.where((session) => session.link == link).firstOrNull;
}
