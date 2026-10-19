import 'dart:async';

import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';
import 'package:gwent/src/features/sound/domain/sound_output.dart';

/// Сценарий: сыграть звуковой эффект с громкостью из настроек (ADR 0023).
///
/// Громкость эффектов держится в памяти и обновляется вместе с настройками, поэтому [call] не ждёт базу и не
/// задерживает ход. Пока настройки не прочитаны, действует громкость по умолчанию. Сценарий живёт столько же, сколько
/// приложение.
final class PlaySound {
  /// Создаёт сценарий и начинает следить за настройками.
  PlaySound(this._output, WatchSettings watchSettings, {this.resumeDelay = const Duration(milliseconds: 400)}) {
    _subscription = watchSettings().listen(
      (settings) => _volume = settings.effectsVolume,
      // Настройки не читаются: звук остаётся на последней известной громкости, а ошибка уходит в обработчик зоны.
      onError: Zone.current.handleUncaughtError,
    );
  }

  /// Сколько после возврата приложения звуки ещё не играют: таймеры и очереди, накопившиеся за время блокировки,
  /// отрабатывают сразу после разблокировки и иначе прозвучали бы залпом.
  final Duration resumeDelay;

  final SoundOutput _output;
  late final StreamSubscription<AppSettings> _subscription;
  int _volume = AppSettings.defaultEffectsVolume;
  bool _suspended = false;
  Timer? _resumeTimer;

  /// Приложение ушло в фон: звуки не играют, пока не вызван [resume] и не пройдёт [resumeDelay].
  void suspend() {
    _resumeTimer?.cancel();
    _suspended = true;
  }

  /// Приложение вернулось: звуки включаются через [resumeDelay].
  void resume() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(resumeDelay, () => _suspended = false);
  }

  /// Готовит эффекты заранее.
  Future<void> preload() => _output.preload();

  /// Перестаёт следить за настройками.
  Future<void> dispose() {
    _resumeTimer?.cancel();
    return _subscription.cancel();
  }

  /// Играет [effect]. [volume] в процентах (0–100) заменяет громкость из настроек: так ползунок громкости даёт
  /// услышать выбранный уровень, ещё не сохранённый.
  void call(SoundEffect effect, {int? volume}) {
    final percent = (volume ?? _volume).clamp(0, AppSettings.maxVolume);
    if (percent == 0 || _suspended) return;
    _output.play(effect, volume: percent / AppSettings.maxVolume);
  }
}
