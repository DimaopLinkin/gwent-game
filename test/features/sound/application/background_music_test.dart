import 'dart:async';
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

  BackgroundMusic buildMusic({required Duration trackGap, required Duration retryDelay}) {
    final created = BackgroundMusic(
      output,
      WatchSettings(settings),
      Random(7),
      trackGap: trackGap,
      retryDelay: retryDelay,
    );
    addTearDown(created.dispose);
    return created;
  }

  setUp(() {
    settings = InMemorySettingsRepository();
    output = FakeMusicOutput();
    // Паузы между композициями и перед повтором в обычных тестах не нужны, повтор «через минуту» не наступает.
    music = buildMusic(trackGap: Duration.zero, retryDelay: const Duration(minutes: 1));
  });

  Future<void> wait(int milliseconds) => Future<void>.delayed(Duration(milliseconds: milliseconds));

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

  test('пауза, пришедшая во время запуска, ставится после него: музыка не оживает', () async {
    output.commandDuration = const Duration(milliseconds: 20);
    final starting = music.start();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final pausing = music.pause();
    await Future.wait([starting, pausing]);
    expect(output.commands.last, 'pause');
    expect(output.commands, isNot(contains('resume')));
  });

  test('пауза и возврат подряд оставляют музыку звучать и не дублируют запуск', () async {
    await music.start();
    output.commandDuration = const Duration(milliseconds: 5);
    await Future.wait([music.pause(), music.resume()]);
    expect(output.commands, isNot(contains('pause')));
    expect(output.tracks, hasLength(1));
  });

  test('не удавшийся запуск не считается звучащей музыкой: возврат из фона пробует ещё раз', () async {
    output.playSucceeds = false;
    await music.start();
    expect(output.tracks, hasLength(1));
    output.playSucceeds = true;
    await music.pause();
    await music.resume();
    expect(output.tracks, hasLength(2));
  });

  test('не удавшийся запуск повторяется сам, без смены громкости и возврата из фона', () async {
    music = buildMusic(trackGap: Duration.zero, retryDelay: const Duration(milliseconds: 10));
    output.playSucceeds = false;
    await music.start();
    output.playSucceeds = true;
    await wait(60);
    expect(output.tracks.length, greaterThanOrEqualTo(2));
    final started = output.tracks.length;
    await finishTrack();
    expect(output.tracks, hasLength(started + 1), reason: 'после удачного повтора музыка идёт дальше сама');
  });

  test('следующая композиция, не запустившаяся после конца прежней, повторяется сама', () async {
    music = buildMusic(trackGap: Duration.zero, retryDelay: const Duration(milliseconds: 10));
    await music.start();
    output.playSucceeds = false;
    await finishTrack();
    output.playSucceeds = true;
    await wait(60);
    expect(output.tracks.length, greaterThanOrEqualTo(3));
    expect(output.commands.last, startsWith('volume:'));
  });

  test('повторы ограничены: сломанный проигрыватель не крутится вечно', () async {
    music = buildMusic(trackGap: Duration.zero, retryDelay: Duration.zero);
    output.playSucceeds = false;
    await music.start();
    await wait(60);
    expect(output.tracks, hasLength(1 + BackgroundMusic.maxRetries));
  });

  test('успешный запуск обнуляет счёт повторов', () async {
    music = buildMusic(trackGap: Duration.zero, retryDelay: Duration.zero);
    output.playSucceeds = false;
    await music.start();
    await wait(60);
    final first = output.tracks.length;
    output.playSucceeds = true;
    await music.pause();
    await music.resume();
    expect(output.tracks, hasLength(first + 1));
    output.playSucceeds = false;
    await finishTrack();
    await wait(60);
    expect(output.tracks, hasLength(first + 2 + BackgroundMusic.maxRetries));
  });

  test('следующая композиция начинается после паузы trackGap, а не мгновенно', () async {
    music = buildMusic(trackGap: const Duration(milliseconds: 40), retryDelay: const Duration(minutes: 1));
    await music.start();
    output.finishTrack();
    await wait(10);
    expect(output.tracks, hasLength(1), reason: 'платформа ещё заканчивает прежнюю композицию');
    await wait(80);
    expect(output.tracks, hasLength(2));
  });

  test('пауза во время промежутка между композициями не даёт новой начаться', () async {
    music = buildMusic(trackGap: const Duration(milliseconds: 30), retryDelay: const Duration(minutes: 1));
    await music.start();
    output.finishTrack();
    await music.pause();
    await wait(80);
    expect(output.tracks, hasLength(1));
  });

  test('два события конца подряд не пропускают композицию и не запускают её дважды', () async {
    music = buildMusic(trackGap: const Duration(milliseconds: 20), retryDelay: const Duration(minutes: 1));
    await music.start();
    output
      ..finishTrack()
      ..finishTrack();
    await wait(80);
    expect(output.tracks, hasLength(2));
  });

  test('пауза и возврат внутри промежутка между композициями не оживляют доигравшую и не дублируют запуск', () async {
    music = buildMusic(trackGap: const Duration(milliseconds: 30), retryDelay: const Duration(minutes: 1));
    await music.start();
    output.finishTrack();
    await music.pause();
    await music.resume();
    await wait(80);
    expect(output.commands, isNot(contains('resume')), reason: 'доигравшая композиция не продолжается');
    expect(output.tracks, hasLength(2));
  });

  test('сброс громкости в ноль и возврат внутри промежутка запускают следующую композицию один раз', () async {
    music = buildMusic(trackGap: const Duration(milliseconds: 30), retryDelay: const Duration(minutes: 1));
    await music.start();
    output.finishTrack();
    await settings.save(const AppSettings(musicVolume: 0));
    await settle();
    await settings.save(const AppSettings(musicVolume: 40));
    await wait(80);
    expect(output.tracks, hasLength(2));
  });

  test('конец композиции после dispose ничего не запускает', () async {
    music = buildMusic(trackGap: const Duration(milliseconds: 20), retryDelay: const Duration(minutes: 1));
    await music.start();
    output.finishTrack();
    await music.dispose();
    await wait(60);
    expect(output.tracks, hasLength(1));
  });

  test('неудачи при ручных запусках не расходуют запас автоповторов', () async {
    music = buildMusic(trackGap: Duration.zero, retryDelay: const Duration(minutes: 1));
    output.playSucceeds = false;
    await music.start();
    for (var i = 0; i < BackgroundMusic.maxRetries + 2; i++) {
      await music.pause();
      await music.resume();
    }
    output.playSucceeds = true;
    final failed = output.tracks.length;
    await music.pause();
    await music.resume();
    expect(output.tracks, hasLength(failed + 1));
  });

  test('ошибка потока настроек не роняет музыку и уходит в обработчик зоны', () async {
    final errors = <Object>[];
    final failing = FakeMusicOutput();
    late BackgroundMusic broken;
    await runZonedGuarded(() async {
      broken = BackgroundMusic(failing, WatchSettings(_BrokenSettingsRepository()), Random(7));
      await broken.start();
      await settle();
    }, (error, _) => errors.add(error));
    addTearDown(broken.dispose);
    expect(errors, [isA<StateError>()]);
    expect(failing.tracks, hasLength(1), reason: 'музыка играет на громкости по умолчанию');
  });
}

/// Настройки, чей поток сразу сообщает об ошибке.
final class _BrokenSettingsRepository extends InMemorySettingsRepository {
  @override
  Stream<AppSettings> watch() => Stream<AppSettings>.error(StateError('настройки не читаются'));
}
