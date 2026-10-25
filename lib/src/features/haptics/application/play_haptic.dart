import 'dart:async';

import 'package:gwent/src/features/haptics/domain/haptic_output.dart';
import 'package:gwent/src/features/haptics/domain/haptic_pattern.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';

/// Сценарий: подать вибрацию с учётом выключателя «Вибрация» в настройках (ADR 0031).
///
/// Выключатель держится в памяти и обновляется вместе с настройками, поэтому [call] не ждёт базу и не задерживает
/// ход. Пока настройки не прочитаны, действует значение по умолчанию (вибрация включена). Громкость звука на вибрацию
/// не влияет. Сценарий живёт столько же, сколько приложение.
final class PlayHaptic {
  /// Создаёт сценарий и начинает следить за настройками.
  PlayHaptic(this._output, WatchSettings watchSettings) {
    _subscription = watchSettings().listen(
      (settings) => _enabled = settings.haptics,
      // Настройки не читаются: вибрация остаётся при последнем известном выключателе, а ошибка уходит в зону.
      onError: Zone.current.handleUncaughtError,
    );
  }

  final HapticOutput _output;
  late final StreamSubscription<AppSettings> _subscription;
  bool _enabled = const AppSettings().haptics;

  /// Перестаёт следить за настройками.
  Future<void> dispose() => _subscription.cancel();

  /// Подаёт [pattern]. [force] играет и при выключенном выключателе: так образец в настройках показывает вибрацию,
  /// ещё не сохранённую.
  void call(HapticPattern pattern, {bool force = false}) {
    if (_enabled || force) _output.play(pattern);
  }
}
