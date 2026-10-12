import 'dart:async';

import 'package:gwent_net/src/time/scheduler.dart';

/// Управляемое время для тестов: таймеры срабатывают только в [elapse].
///
/// Между срабатываниями таймеров выполняются микрозадачи и доставка кадров, поэтому ответ на `ping`
/// успевает прийти раньше тайм-аута связи, как и в реальном времени.
final class FakeScheduler implements Scheduler {
  Duration _now = Duration.zero;
  int _created = 0;
  final List<_FakeTimer> _timers = [];

  /// Сколько прошло управляемого времени.
  Duration get now => _now;

  @override
  Timer timer(Duration delay, void Function() callback) => _add(delay, callback, null);

  @override
  Timer periodic(Duration period, void Function() callback) =>
      _add(period, callback, period > Duration.zero ? period : const Duration(microseconds: 1));

  /// Продвигает время на [duration], по порядку вызывая таймеры, которым пора.
  Future<void> elapse(Duration duration) async {
    final target = _now + duration;
    await flush();
    while (true) {
      final due = _timers.where((timer) => timer.dueAt <= target).toList()
        ..sort((a, b) => a.dueAt != b.dueAt ? a.dueAt.compareTo(b.dueAt) : a.order.compareTo(b.order));
      if (due.isEmpty) break;
      final timer = due.first;
      _now = timer.dueAt;
      timer.fire();
      await flush();
    }
    _now = target;
  }

  /// Выполняет накопившиеся микрозадачи и доставку кадров, не двигая время.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  _FakeTimer _add(Duration delay, void Function() callback, Duration? period) {
    final timer = _FakeTimer(this, _now + delay, _created++, callback, period);
    _timers.add(timer);
    return timer;
  }
}

final class _FakeTimer implements Timer {
  _FakeTimer(this._scheduler, this.dueAt, this.order, this._callback, this._period);

  final FakeScheduler _scheduler;
  final void Function() _callback;
  final Duration? _period;
  Duration dueAt;
  int order;
  int _tick = 0;

  @override
  bool get isActive => _scheduler._timers.contains(this);

  @override
  int get tick => _tick;

  @override
  void cancel() => _scheduler._timers.remove(this);

  void fire() {
    _tick++;
    final period = _period;
    if (period == null) {
      cancel();
    } else {
      dueAt += period;
      order = _scheduler._created++;
    }
    _callback();
  }
}
