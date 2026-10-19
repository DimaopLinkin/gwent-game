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
  PlaySound(this._output, WatchSettings watchSettings) {
    _subscription = watchSettings().listen(
      (settings) => _volume = settings.effectsVolume,
      // Настройки не читаются: звук остаётся на последней известной громкости, а ошибка уходит в обработчик зоны.
      onError: Zone.current.handleUncaughtError,
    );
  }

  final SoundOutput _output;
  late final StreamSubscription<AppSettings> _subscription;
  int _volume = AppSettings.defaultEffectsVolume;

  /// Готовит эффекты заранее.
  Future<void> preload() => _output.preload();

  /// Перестаёт следить за настройками.
  Future<void> dispose() => _subscription.cancel();

  /// Играет [effect]. [volume] в процентах (0–100) заменяет громкость из настроек: так ползунок громкости даёт
  /// услышать выбранный уровень, ещё не сохранённый.
  void call(SoundEffect effect, {int? volume}) {
    final percent = (volume ?? _volume).clamp(0, AppSettings.maxVolume);
    if (percent == 0) return;
    _output.play(effect, volume: percent / AppSettings.maxVolume);
  }
}
