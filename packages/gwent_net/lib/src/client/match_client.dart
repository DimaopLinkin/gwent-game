import 'dart:async';

import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/client/client_event.dart';
import 'package:gwent_net/src/client/client_settings.dart';
import 'package:gwent_net/src/client/resume_ticket.dart';
import 'package:gwent_net/src/codec/protocol_exception.dart';
import 'package:gwent_net/src/protocol/envelope.dart';
import 'package:gwent_net/src/protocol/net_message.dart';
import 'package:gwent_net/src/session/peer_link.dart';
import 'package:gwent_net/src/session/sequenced_channel.dart';
import 'package:gwent_net/src/time/scheduler.dart';
import 'package:gwent_net/src/transport/transport.dart';

/// Состояние связи клиента с хостом.
enum ConnectionStatus {
  /// Транспорта нет: ещё не подключались или связь потеряна.
  offline,

  /// `hello` отправлен, ждём `welcome`.
  joining,

  /// Место получено, сообщения идут.
  online,

  /// Хост не пустил.
  refused,
}

/// Игрок партии: шлёт хосту колоду и намерения, хранит свою проекцию (раздел 2 сетевой спецификации).
///
/// Намерения, отправленные без связи, ждут в очереди и уходят после переподключения. Переподключение
/// делает приложение: получает новый транспорт (лобби, QR, другой вид связи) и вызывает [connect].
final class MatchClient {
  MatchClient({required ClientSettings settings, required Scheduler scheduler, ResumeTicket? ticket})
    : _settings = settings,
      _scheduler = scheduler,
      _ticket = ticket,
      _channel = SequencedChannel(matchId: ticket?.matchId);

  final ClientSettings _settings;
  final Scheduler _scheduler;
  final SequencedChannel _channel;
  final StreamController<ClientEvent> _events = StreamController<ClientEvent>.broadcast();

  ResumeTicket? _ticket;
  PeerLink? _link;
  Timer? _ping;
  ConnectionStatus _status = ConnectionStatus.offline;
  Seat? _seat;
  PlayerView? _view;

  /// Сколько сообщений этого места хост принял до первого `welcome` этому экземпляру; `null` до него.
  int? _base;
  final List<ClientMessage> _unnumbered = [];

  Stream<ClientEvent> get events => _events.stream;

  ConnectionStatus get status => _status;

  /// Место в партии; `null` до первого `welcome`.
  Seat? get seat => _seat;

  /// Последняя проекция партии; `null` до её начала.
  PlayerView? get view => _view;

  /// Билет для возвращения в партию; `null` до первого `welcome`.
  ResumeTicket? get ticket => _ticket;

  /// Подключается к хосту через [transport]; прежнее соединение, если есть, закрывается.
  void connect(Transport transport) {
    final previous = _link;
    _link = null;
    _ping?.cancel();
    if (previous != null) unawaited(previous.close());
    final link = PeerLink(
      transport,
      scheduler: _scheduler,
      timeout: _settings.linkTimeout,
      onEnvelope: _onEnvelope,
      onMalformed: _onMalformed,
      onLost: _onLost,
    );
    _link = link;
    _status = ConnectionStatus.joining;
    final hello = Hello(
      ruleset: _settings.ruleset,
      playerName: _settings.playerName,
      appVersion: _settings.appVersion,
      resumeToken: _ticket?.token,
    );
    link.send(_channel.control(hello));
  }

  /// Отправляет колоду; возвращает номер запроса, на который сошлётся `ActionRefused.request`.
  int submitDeck(Deck deck) => _sendSequenced(DeckSubmission(deck));

  /// Отправляет намерение; возвращает номер запроса, на который сошлётся `ActionRefused.request`.
  int send(Intent intent) => _sendSequenced(IntentMessage(intent));

  /// Закрывает соединение и поток событий.
  Future<void> close() async {
    _ping?.cancel();
    final link = _link;
    _link = null;
    await link?.close();
    await _events.close();
  }

  /// Номера запросов идут с 1 в этом экземпляре клиента. Номер на проводе — `_base + запрос`: до первого
  /// `welcome` клиент не знает, сколько сообщений хост уже принял от этого места (после перезапуска с билетом
  /// это сообщения прежнего экземпляра), поэтому до него сообщения ждут без номера.
  int _sendSequenced(ClientMessage message) {
    final base = _base;
    if (base == null) {
      _unnumbered.add(message);
      return _unnumbered.length;
    }
    final envelope = _channel.sequenced(message);
    if (_status == ConnectionStatus.online) _link?.send(envelope);
    return envelope.seq - base;
  }

  void _onEnvelope(PeerLink link, Envelope envelope) {
    if (link != _link) return;
    switch (_channel.receive(envelope)) {
      case Delivery.control:
        _onControl(link, envelope);
      case Delivery.next:
        _onSequenced(link, envelope.message);
      case Delivery.gap:
        if (_channel.claimResendRequest()) link.send(_channel.control(const ResendRequest()));
      case Delivery.duplicate:
        break;
    }
  }

  void _onControl(PeerLink link, Envelope envelope) {
    switch (envelope.message) {
      case final Welcome welcome:
        _onWelcome(link, welcome, envelope.ack);
      case JoinRejected(:final reason, :final protocol):
        _status = ConnectionStatus.refused;
        _emit(JoinRefused(reason, hostProtocol: protocol));
        unawaited(link.close());
      case Pong(:final sent):
        if (sent > _channel.received) link.send(_channel.control(const ResendRequest()));
      case ResendRequest():
        if (_status == ConnectionStatus.online) _channel.pending().forEach(link.send);
      case Hello() || Ping() || ClientMessage() || HostMessage():
        // Хост такое не шлёт; номерные сообщения сюда не попадают.
        break;
    }
  }

  void _onWelcome(PeerLink link, Welcome welcome, int hostAck) {
    _seat = welcome.seat;
    _ticket = ResumeTicket(matchId: welcome.matchId, token: welcome.resumeToken);
    _channel
      ..matchId = welcome.matchId
      ..expectNext(welcome.next);
    if (_base == null) {
      _base = hostAck;
      _channel.startAfter(hostAck);
      _unnumbered.forEach(_channel.sequenced);
      _unnumbered.clear();
    }
    _status = ConnectionStatus.online;
    _ping?.cancel();
    _ping = _scheduler.periodic(_settings.pingInterval, _sendPing);
    _emit(Joined(welcome.seat));
    _channel.pending().forEach(link.send);
  }

  void _onSequenced(PeerLink link, NetMessage message) {
    switch (message) {
      case MatchUpdate(:final events, :final view):
        _view = view;
        _emit(ViewChanged(view, events));
      case MatchSnapshot(:final view):
        _view = view;
        _emit(ViewChanged(view, const []));
      case final Refusal refusal:
        _emit(ActionRefused(refusal, request: refusal.replyTo - (_base ?? 0)));
      case OpponentPresence(:final online, :final name):
        _emit(OpponentPresenceChanged(online: online, name: name));
      case ControlMessage() || ClientMessage():
        // Нарушение протокола: сообщение клиента от хоста.
        unawaited(link.close());
    }
  }

  void _sendPing() {
    final link = _link;
    if (link != null && _status == ConnectionStatus.online) link.send(_channel.control(Ping(sent: _channel.sent)));
  }

  void _onMalformed(PeerLink link, ProtocolException error) => unawaited(link.close());

  void _onLost(PeerLink link) {
    if (link != _link) return;
    _link = null;
    _ping?.cancel();
    _ping = null;
    if (_status == ConnectionStatus.refused) return;
    _status = ConnectionStatus.offline;
    _emit(const ConnectionLost());
  }

  void _emit(ClientEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
