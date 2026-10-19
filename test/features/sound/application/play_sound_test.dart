import 'package:flutter_test/flutter_test.dart';
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

  test('подготовка уходит в вывод', () async {
    await sound.preload();
    expect(output.preloads, 1);
  });
}
