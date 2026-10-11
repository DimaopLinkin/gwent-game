import 'package:gwent/src/core/domain/clock.dart';

/// Системные часы устройства.
final class SystemClock implements Clock {
  /// Создаёт системные часы.
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
