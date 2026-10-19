import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:gwent/src/features/sound/data/game_audio_context.dart';
import 'package:gwent/src/features/sound/domain/music_output.dart';
import 'package:gwent/src/features/sound/domain/music_track.dart';

/// Музыка через `audioplayers` (ADR 0023): один проигрыватель, композиции по очереди.
///
/// Файлы лежат в `assets/music/` в формате AAC (`.m4a`). Проигрыватель создаётся при первом обращении. Звуковой контекст
/// общий с эффектами (`configureGameAudioContext`). Команды идут одной очередью: многошаговый запуск не перемежается с
/// паузой или громкостью, а проигрыватель создаётся один раз. Сбой воспроизведения уходит в
/// `FlutterError.reportError`, игра продолжается без музыки.
final class AudioplayersMusicOutput implements MusicOutput {
  /// Создаёт вывод; [assetDirectory] — папка с файлами внутри `assets/`.
  AudioplayersMusicOutput({this.assetDirectory = 'music'});

  /// Папка с файлами внутри `assets/`.
  final String assetDirectory;

  AudioPlayer? _player;
  Future<void> _tail = Future<void>.value();
  final StreamController<void> _ended = StreamController<void>.broadcast();

  /// Имя файла композиции без папки.
  @visibleForTesting
  static String fileName(MusicTrack track) => switch (track) {
    MusicTrack.mustyScentOfFreshPate => 'musty_scent_of_fresh_pate.m4a',
    MusicTrack.anotherRoundForEveryone => 'another_round_for_everyone.m4a',
    MusicTrack.backOnThePath => 'back_on_the_path.m4a',
    MusicTrack.aStoryYouWontBelieve => 'a_story_you_wont_believe.m4a',
    MusicTrack.theNightingale => 'the_nightingale.m4a',
    MusicTrack.cloakAndDagger => 'cloak_and_dagger.m4a',
    MusicTrack.drinkUpTheresMore => 'drink_up_theres_more.m4a',
  };

  @override
  Stream<void> get trackEnded => _ended.stream;

  @override
  Future<bool> play(MusicTrack track, {required double volume}) => _guard('запуск ${track.name}', (player) async {
    await player.stop();
    await player.setVolume(volume);
    await player.play(AssetSource('$assetDirectory/${fileName(track)}'));
  });

  @override
  Future<void> setVolume(double volume) async {
    await _guard('громкость', (player) => player.setVolume(volume));
  }

  @override
  Future<void> pause() async {
    await _guard('пауза', (player) => player.pause());
  }

  @override
  Future<void> resume() async {
    await _guard('продолжение', (player) => player.resume());
  }

  Future<AudioPlayer> _create() async {
    await configureGameAudioContext();
    final player = AudioPlayer();
    player.onPlayerComplete.listen((_) => _ended.add(null));
    return player;
  }

  /// Ставит команду в очередь; `true`, если она выполнилась без ошибки.
  Future<bool> _guard(String action, Future<void> Function(AudioPlayer player) body) {
    final run = _tail.then((_) => _run(action, body));
    _tail = run;
    return run;
  }

  Future<bool> _run(String action, Future<void> Function(AudioPlayer player) body) async {
    try {
      final player = _player ??= await _create();
      await body(player);
      return true;
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace, library: 'музыка', context: ErrorDescription(action)),
      );
      return false;
    }
  }
}
