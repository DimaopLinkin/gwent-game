import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/time/scheduler.dart';
import 'package:gwent_net/src/transport/transport.dart';

/// Какие неполадки изображать (раздел 6.1 сетевой спецификации).
final class Faults extends Value {
  const Faults({this.drop = 0, this.duplicate = 0, this.maxDelay = Duration.zero});

  /// Без неполадок.
  static const Faults none = Faults();

  /// Доля потерянных кадров, от 0 до 1.
  final double drop;

  /// Доля кадров, которые придут дважды.
  final double duplicate;

  /// Наибольшая задержка кадра. Порядок кадров сохраняется, как в TCP и в характеристике BLE.
  final Duration maxDelay;

  @override
  List<Object?> get props => [drop, duplicate, maxDelay];
}

/// Обёртка транспорта с потерями, дублями, задержками и обрывом. Неполадки действуют в обе стороны
/// и воспроизводятся по сиду.
final class FaultyTransport implements Transport {
  FaultyTransport(this._inner, {required Scheduler scheduler, this.faults = Faults.none, int seed = 0})
    : _rng = SeededRng(seed) {
    _outgoing = _Lane(scheduler, _inner.send);
    _incomingLane = _Lane(scheduler, _deliver);
    _subscription = _inner.incoming.listen((frame) => _pass(frame, _incomingLane), onDone: _lost);
  }

  final Transport _inner;
  final StreamController<Uint8List> _incoming = StreamController<Uint8List>();
  late final _Lane _outgoing;
  late final _Lane _incomingLane;
  late final StreamSubscription<Uint8List> _subscription;
  Rng _rng;

  /// Текущие неполадки; их можно менять по ходу теста.
  Faults faults;

  /// Сколько кадров потеряно.
  int dropped = 0;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  void send(Uint8List frame) => _pass(frame, _outgoing);

  /// Обрывает связь, как выход из зоны Wi-Fi: обе стороны видят закрытие.
  Future<void> cut() => close();

  @override
  Future<void> close() async {
    await _inner.close();
    _lost();
  }

  void _pass(Uint8List frame, _Lane lane) {
    if (_incoming.isClosed) return;
    if (_chance(faults.drop)) {
      dropped++;
      return;
    }
    final copies = _chance(faults.duplicate) ? 2 : 1;
    for (var i = 0; i < copies; i++) {
      lane.push(frame, _delay());
    }
  }

  void _deliver(Uint8List frame) {
    if (!_incoming.isClosed) _incoming.add(frame);
  }

  void _lost() {
    if (_incoming.isClosed) return;
    _outgoing.stop();
    _incomingLane.stop();
    unawaited(_subscription.cancel());
    unawaited(_incoming.close());
  }

  bool _chance(double probability) {
    if (probability <= 0) return false;
    final (value, next) = _rng.nextInt(1000000);
    _rng = next;
    return value < probability * 1000000;
  }

  Duration _delay() {
    final max = faults.maxDelay.inMicroseconds;
    if (max <= 0) return Duration.zero;
    final (value, next) = _rng.nextInt(max + 1);
    _rng = next;
    return Duration(microseconds: value);
  }
}

/// Очередь кадров одного направления: задержанный кадр задерживает и следующие за ним.
final class _Lane {
  _Lane(this._scheduler, this._sink);

  final Scheduler _scheduler;
  final void Function(Uint8List frame) _sink;
  final Queue<(Uint8List, Duration)> _queue = Queue();
  Timer? _timer;
  bool _stopped = false;

  void push(Uint8List frame, Duration delay) {
    if (_stopped) return;
    if (delay == Duration.zero && _queue.isEmpty) {
      _sink(frame);
      return;
    }
    _queue.add((frame, delay));
    if (_timer == null) _next();
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
    _queue.clear();
  }

  void _next() {
    if (_queue.isEmpty) {
      _timer = null;
      return;
    }
    _timer = _scheduler.timer(_queue.first.$2, () {
      if (_stopped) return;
      _sink(_queue.removeFirst().$1);
      _next();
    });
  }
}
