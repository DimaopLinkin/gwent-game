import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/sound/application/background_music.dart';
import 'package:gwent/src/features/sound/domain/music_track.dart';

import '../../../support/fakes.dart';

void main() {
  late InMemorySettingsRepository settings;
  late FakeMusicOutput output;
  late BackgroundMusic music;

  setUp(() {
    settings = InMemorySettingsRepository();
    output = FakeMusicOutput();
    music = BackgroundMusic(output, WatchSettings(settings), Random(7));
    addTearDown(music.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Композиция доиграла, и следующая успела начаться.
  Future<void> finishTrack() async {
    output.finishTrack();
    await settle();
  }

  test('пока музыку не запустили, она молчит', () async {
    await settle();
    expect(output.commands, isEmpty);
  });

  test('запуск начинает одну композицию с громкостью из настроек по умолчанию', () async {
    await music.start();
    expect(output.tracks, hasLength(1));
    expect(output.commands.last, 'volume:${AppSettings.defaultMusicVolume / AppSettings.maxVolume}');
  });

  test('повторный запуск ничего не меняет', () async {
    await music.start();
    await music.start();
    expect(output.tracks, hasLength(1));
  });

  test('за круг каждая композиция звучит один раз, и круги не начинаются с повтора', () async {
    await music.start();
    for (var i = 0; i < MusicTrack.values.length * 4; i++) {
      await finishTrack();
    }
    final tracks = output.tracks;
    for (var round = 0; round < 4; round++) {
      final lap = tracks.skip(round * MusicTrack.values.length).take(MusicTrack.values.length);
      expect(lap.toSet(), MusicTrack.values.toSet(), reason: 'круг ${round + 1}');
    }
    for (var i = 1; i < tracks.length; i++) {
      expect(tracks[i], isNot(tracks[i - 1]), reason: 'подряд одна и та же композиция на $i');
    }
  });

  test('громкость из настроек применяется на лету', () async {
    await music.start();
    await settings.save(const AppSettings(musicVolume: 30));
    await settle();
    expect(output.commands.last, 'volume:0.3');
  });

  test('нулевая громкость ставит музыку на паузу, возврат громкости продолжает ту же композицию', () async {
    await music.start();
    await settings.save(const AppSettings(musicVolume: 0));
    await settle();
    expect(output.commands.last, 'pause');
    await settings.save(const AppSettings(musicVolume: 60));
    await settle();
    expect(output.commands.sublist(output.commands.length - 2), ['volume:0.6', 'resume']);
    expect(output.tracks, hasLength(1), reason: 'композиция не началась заново');
  });

  test('музыка, запущенная при нулевой громкости, начнётся, когда громкость вернётся', () async {
    await settings.save(const AppSettings(musicVolume: 0));
    await settle();
    await music.start();
    expect(output.commands, isEmpty);
    await settings.save(const AppSettings(musicVolume: 50));
    await settle();
    expect(output.tracks, hasLength(1));
  });

  test('фон: пауза и возврат продолжают, а не начинают заново', () async {
    await music.start();
    await music.pause();
    expect(output.commands.last, 'pause');
    await music.resume();
    expect(output.commands.last, 'resume');
    expect(output.tracks, hasLength(1));
  });

  test('пока приложение в фоне, конец композиции новую не запускает', () async {
    await music.start();
    await music.pause();
    final before = output.commands.length;
    await finishTrack();
    expect(output.commands, hasLength(before));
  });

  test('изменение настроек, не затрагивающее музыку, команд не даёт', () async {
    await music.start();
    final before = output.commands.length;
    await settings.save(const AppSettings(effectsVolume: 10));
    await settle();
    expect(output.commands, hasLength(before));
  });
}
