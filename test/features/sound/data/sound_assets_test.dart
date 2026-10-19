import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/sound/data/audioplayers_music_output.dart';
import 'package:gwent/src/features/sound/data/audioplayers_sound_output.dart';
import 'package:gwent/src/features/sound/domain/music_track.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';

/// Файлы в `assets/sfx` и `assets/music` и перечисления в коде не должны разойтись: иначе эффект молчит на устройстве,
/// а в тестах с фальшивым выводом этого не видно.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Set<String> filesIn(String directory) => {
    for (final entity in Directory(directory).listSync())
      if (entity is File && entity.path.endsWith('.m4a')) entity.uri.pathSegments.last,
  };

  test('у каждого эффекта есть свой файл в assets/sfx, и других файлов там нет', () {
    final names = [for (final effect in SoundEffect.values) AudioplayersSoundOutput.fileName(effect)];
    expect(names.toSet(), hasLength(SoundEffect.values.length), reason: 'два эффекта делят файл');
    expect(filesIn('assets/sfx'), names.toSet());
  });

  test('эффекты, готовящиеся заранее, не повторяются и помещаются в число живых проигрывателей', () {
    const core = AudioplayersSoundOutput.coreEffects;
    expect(core.toSet(), hasLength(core.length));
    expect(core.length, lessThanOrEqualTo(AudioplayersSoundOutput.defaultMaxPlayers));
  });

  test('у каждой композиции есть свой файл в assets/music, и других файлов там нет', () {
    final names = [for (final track in MusicTrack.values) AudioplayersMusicOutput.fileName(track)];
    expect(names.toSet(), hasLength(MusicTrack.values.length), reason: 'две композиции делят файл');
    expect(filesIn('assets/music'), names.toSet());
  });

  test('файлы объявлены в pubspec: приложение находит их в пакете ассетов', () async {
    for (final effect in SoundEffect.values) {
      final data = await rootBundle.load('assets/sfx/${AudioplayersSoundOutput.fileName(effect)}');
      expect(data.lengthInBytes, greaterThan(0), reason: effect.name);
    }
    for (final track in MusicTrack.values) {
      final data = await rootBundle.load('assets/music/${AudioplayersMusicOutput.fileName(track)}');
      expect(data.lengthInBytes, greaterThan(0), reason: track.name);
    }
  });
}
