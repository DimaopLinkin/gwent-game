import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/haptics/application/play_haptic.dart';
import 'package:gwent/src/features/haptics/domain/haptic_pattern.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/sound/application/play_sound.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';

import '../../../support/fakes.dart';

void main() {
  late InMemorySettingsRepository settings;
  late RecordingSoundOutput output;
  late PlaySound sound;

  setUp(() {
    settings = InMemorySettingsRepository();
    output = RecordingSoundOutput();
    sound = PlaySound(output, WatchSettings(settings));
    addTearDown(sound.dispose);
  });

  /// Даёт потоку настроек доставить значение.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('до чтения настроек играет с громкостью по умолчанию', () {
    sound(SoundEffect.pass);
    expect(output.played.single.volume, AppSettings.defaultEffectsVolume / AppSettings.maxVolume);
  });

  test('громкость берётся из настроек и меняется вместе с ними', () async {
    await settings.save(const AppSettings(effectsVolume: 40));
    await settle();
    sound(SoundEffect.draw);
    await settings.save(const AppSettings(effectsVolume: 100));
    await settle();
    sound(SoundEffect.draw);
    expect(output.played.map((entry) => entry.volume), [0.4, 1.0]);
  });

  test('нулевая громкость не играет ничего', () async {
    await settings.save(const AppSettings(effectsVolume: 0));
    await settle();
    sound(SoundEffect.horn);
    expect(output.played, isEmpty);
  });

  test('громкость образца заменяет сохранённую, не меняя её', () async {
    await settings.save(const AppSettings(effectsVolume: 0));
    await settle();
    sound(SoundEffect.turnMine, volume: 50);
    expect(output.played.single.volume, 0.5);
    sound(SoundEffect.turnMine);
    expect(output.played, hasLength(1), reason: 'сохранённая громкость по-прежнему нулевая');
  });

  test('образец с громкостью вне 0–100 зажимается', () {
    sound(SoundEffect.select, volume: 250);
    expect(output.played.single.volume, 1);
  });

  test('в фоне звуки не играют, а после возврата включаются не сразу', () async {
    final delayed = PlaySound(output, WatchSettings(settings), resumeDelay: const Duration(milliseconds: 30));
    addTearDown(delayed.dispose);
    delayed.suspend();
    delayed(SoundEffect.select);
    expect(output.played, isEmpty);
    delayed.resume();
    delayed(SoundEffect.select);
    expect(
      output.played,
      isEmpty,
      reason: 'таймеры, накопившиеся за блокировку, отрабатывают сразу после разблокировки',
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    delayed(SoundEffect.select);
    expect(output.played, hasLength(1));
  });

  test('повторный уход в фон во время задержки возврата снова глушит звук', () async {
    final delayed = PlaySound(output, WatchSettings(settings), resumeDelay: const Duration(milliseconds: 30));
    addTearDown(delayed.dispose);
    delayed
      ..suspend()
      ..resume()
      ..suspend();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    delayed(SoundEffect.select);
    expect(output.played, isEmpty);
  });

  group('вибрация события (ADR 0031)', () {
    late RecordingHapticOutput haptics;
    late PlaySound withHaptics;

    setUp(() {
      haptics = RecordingHapticOutput();
      final haptic = PlayHaptic(haptics, WatchSettings(settings));
      addTearDown(haptic.dispose);
      withHaptics = PlaySound(output, WatchSettings(settings), haptic: haptic);
      addTearDown(withHaptics.dispose);
    });

    test('событие вибрирует по таблице вместе со звуком', () {
      withHaptics(SoundEffect.scorch);
      expect(haptics.played, [HapticPattern.rumble]);
      expect(output.effects, [SoundEffect.scorch]);
    });

    test('при нулевой громкости звука нет, а вибрация есть', () async {
      await settings.save(const AppSettings(effectsVolume: 0));
      await settle();
      withHaptics(SoundEffect.horn);
      expect(output.played, isEmpty);
      expect(haptics.played, [HapticPattern.knock]);
    });

    test('событие без паттерна и образец громкости не вибрируют', () {
      withHaptics(SoundEffect.turnOpponent);
      withHaptics(SoundEffect.turnMine, volume: 50);
      expect(haptics.played, isEmpty);
    });

    test('в фоне не вибрирует', () {
      withHaptics
        ..suspend()
        ..call(SoundEffect.pass);
      expect(haptics.played, isEmpty);
    });
  });

  test('подготовка уходит в вывод', () async {
    await sound.preload();
    expect(output.preloads, 1);
  });
}
