import 'dart:async';
import 'dart:typed_data';

import 'package:gwent_net/src/codec/envelope_codec.dart';
import 'package:gwent_net/src/codec/protocol_exception.dart';
import 'package:gwent_net/src/protocol/envelope.dart';
import 'package:gwent_net/src/time/scheduler.dart';
import 'package:gwent_net/src/transport/transport.dart';

/// Одно соединение на уровне конвертов: кодирует и разбирает кадры и следит, что собеседник жив.
///
/// Если от собеседника нет кадров дольше [timeout] (полуоткрытый сокет, BLE вне зоны), соединение
/// закрывается. [onLost] вызывается ровно один раз: при обрыве, по тайм-ауту или после [close].
///
/// Раньше тайм-аута связь называется нестабильной: если кадров нет дольше [quietAfter], [onQuiet] вызывается
/// с `true`, а когда кадры пошли снова, с `false`.
final class PeerLink {
  PeerLink(
    this._transport, {
    required Scheduler scheduler,
    required this.timeout,
    required void Function(PeerLink link, Envelope envelope) onEnvelope,
    required void Function(PeerLink link, ProtocolException error) onMalformed,
    required void Function(PeerLink link) onLost,
    this.quietAfter,
    void Function(PeerLink link, {required bool quiet})? onQuiet,
    EnvelopeCodec codec = const EnvelopeCodec(),
  }) : _scheduler = scheduler,
       _codec = codec,
       _onEnvelope = onEnvelope,
       _onMalformed = onMalformed,
       _onLost = onLost,
       _onQuiet = onQuiet {
    _subscription = _transport.incoming.listen(_onFrame, onDone: _lost);
    _watchdog = _scheduler.timer(timeout, _timedOut);
    _watchQuiet();
  }

  final Transport _transport;
  final Scheduler _scheduler;
  final EnvelopeCodec _codec;
  final void Function(PeerLink link, Envelope envelope) _onEnvelope;
  final void Function(PeerLink link, ProtocolException error) _onMalformed;
  final void Function(PeerLink link) _onLost;
  final void Function(PeerLink link, {required bool quiet})? _onQuiet;

  /// Сколько можно молчать собеседнику.
  final Duration timeout;

  /// Через сколько молчания связь считается нестабильной; `null` — не следить.
  final Duration? quietAfter;

  late final StreamSubscription<Uint8List> _subscription;
  late Timer _watchdog;
  Timer? _quietWatch;
  bool _quiet = false;
  bool _closed = false;

  bool get isClosed => _closed;

  void send(Envelope envelope) {
    if (!_closed) _transport.send(_codec.encode(envelope));
  }

  /// Закрывает соединение; [onLost] вызывается сразу.
  Future<void> close() async {
    if (_closed) return;
    _lost();
    await _transport.close();
  }

  void _onFrame(Uint8List frame) {
    if (_closed) return;
    _watchdog.cancel();
    _watchdog = _scheduler.timer(timeout, _timedOut);
    _watchQuiet();
    if (_quiet) {
      _quiet = false;
      _onQuiet?.call(this, quiet: false);
    }
    final Envelope envelope;
    try {
      envelope = _codec.decode(frame);
    } on ProtocolException catch (error) {
      _onMalformed(this, error);
      return;
    }
    _onEnvelope(this, envelope);
  }

  void _timedOut() => unawaited(close());

  void _watchQuiet() {
    final after = quietAfter;
    if (after == null || _onQuiet == null) return;
    _quietWatch?.cancel();
    _quietWatch = _scheduler.timer(after, () {
      if (_closed) return;
      _quiet = true;
      _onQuiet(this, quiet: true);
    });
  }

  void _lost() {
    if (_closed) return;
    _closed = true;
    _watchdog.cancel();
    _quietWatch?.cancel();
    unawaited(_subscription.cancel());
    _onLost(this);
  }
}
