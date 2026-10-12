import 'dart:async';

/// Таймеры протокола: проверка связи, ожидание переподключения. В тестах подставляется управляемое время.
abstract interface class Scheduler {
  /// Однократный вызов через [delay].
  Timer timer(Duration delay, void Function() callback);

  /// Вызов каждые [period].
  Timer periodic(Duration period, void Function() callback);
}

/// Таймеры `dart:async`.
final class SystemScheduler implements Scheduler {
  const SystemScheduler();

  @override
  Timer timer(Duration delay, void Function() callback) => Timer(delay, callback);

  @override
  Timer periodic(Duration period, void Function() callback) => Timer.periodic(period, (_) => callback());
}
