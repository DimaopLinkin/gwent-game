import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:gwent/src/features/sound/data/game_audio_context.dart';
import 'package:gwent/src/features/sound/data/recent_slots.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';
import 'package:gwent/src/features/sound/domain/sound_output.dart';

/// Звук через `audioplayers` (ADR 0023): на каждый эффект один проигрыватель в режиме низкой задержки.
///
/// Файлы лежат в `assets/sfx/` в формате AAC (`.m4a`), один набор на Android и iOS. Проигрыватель создаётся при первом
/// обращении к эффекту (или заранее, в [preload]). Живых проигрывателей не больше [maxPlayers]: на iOS каждый из них
/// держит свой `AVPlayer`, и три десятка одновременно (по одному на эффект, да ещё с музыкой) уже мешают друг другу
/// и музыке. Когда место кончилось, закрывается проигрыватель, которым дольше всего не пользовались, а эффект,
/// которого сейчас нет, создаётся заново при запуске. Повторный запуск эффекта сначала останавливает прежний: в
/// режиме низкой задержки проигрыватель сам не узнаёт, что звук кончился.
///
/// Звуковой контекст (чужой звук не прерывается) задаёт `configureGameAudioContext`. Сбой воспроизведения (нет файла, нет плагина) уходит в
/// `FlutterError.reportError`, игра продолжается без звука.
final class AudioplayersSoundOutput implements SoundOutput {
  /// Создаёт вывод; [assetDirectory] — папка с файлами внутри `assets/`, [maxPlayers] — сколько проигрывателей
  /// держать живыми.
  AudioplayersSoundOutput({this.assetDirectory = 'sfx', int maxPlayers = defaultMaxPlayers})
    : _players = RecentSlots(maxPlayers);

  /// Сколько проигрывателей эффектов держать живыми по умолчанию.
  static const int defaultMaxPlayers = 12;

  /// Эффекты, которые нужны сразу: меню, выбор карты, ход, самые частые звуки розыгрыша. Остальные создаются при
  /// первом запуске.
  @visibleForTesting
  static const List<SoundEffect> coreEffects = [
    SoundEffect.menuOpen,
    SoundEffect.select,
    SoundEffect.turnMine,
    SoundEffect.turnOpponent,
    SoundEffect.unitMelee,
    SoundEffect.unitRanged,
    SoundEffect.unitSiege,
    SoundEffect.draw,
    SoundEffect.pass,
    SoundEffect.warning,
  ];

  /// Папка с файлами внутри `assets/`.
  final String assetDirectory;

  final RecentSlots<SoundEffect, Future<AudioPlayer>> _players;
  final Map<SoundEffect, Future<void>> _queues = {};

  /// Имя файла эффекта без папки.
  @visibleForTesting
  static String fileName(SoundEffect effect) => switch (effect) {
    SoundEffect.matchOpening => 'game_opening.m4a',
    SoundEffect.matchStart => 'game_start.m4a',
    SoundEffect.redraw => 'redraw.m4a',
    SoundEffect.firstRoundStart => 'round1_start.m4a',
    SoundEffect.turnMine => 'turn_me.m4a',
    SoundEffect.turnOpponent => 'turn_op.m4a',
    SoundEffect.pass => 'pass.m4a',
    SoundEffect.roundWon => 'round_win.m4a',
    SoundEffect.roundLost => 'round_lose.m4a',
    SoundEffect.matchWon => 'game_win.m4a',
    SoundEffect.matchLost => 'game_lose.m4a',
    SoundEffect.draw => 'draw.m4a',
    SoundEffect.unitMelee => 'common_close.m4a',
    SoundEffect.unitRanged => 'common_ranged.m4a',
    SoundEffect.unitSiege => 'common_siege.m4a',
    SoundEffect.hero => 'hero.m4a',
    SoundEffect.spy => 'spy.m4a',
    SoundEffect.medic => 'medic.m4a',
    SoundEffect.muster => 'muster.m4a',
    SoundEffect.morale => 'morale.m4a',
    SoundEffect.bond => 'bond.m4a',
    SoundEffect.horn => 'horn.m4a',
    SoundEffect.mardroeme => 'mardroeme.m4a',
    SoundEffect.scorch => 'scorch.m4a',
    SoundEffect.decoy => 'decoy.m4a',
    SoundEffect.clearWeather => 'clear.m4a',
    SoundEffect.frost => 'frost.m4a',
    SoundEffect.fog => 'fog.m4a',
    SoundEffect.rain => 'rain.m4a',
    SoundEffect.select => 'ui_card.m4a',
    SoundEffect.sheetOpen => 'open.m4a',
    SoundEffect.deckAdd => 'ui_card_bank.m4a',
    SoundEffect.deckRemove => 'discard.m4a',
    SoundEffect.warning => 'warning.m4a',
    SoundEffect.menuOpen => 'menu_opening.m4a',
  };

  @override
  Future<void> preload() async {
    // По одному: три десятка плееров, созданных разом, задерживают музыку, которая стартует рядом.
    for (final effect in coreEffects) {
      try {
        await _player(effect);
      } on Object catch (error, stackTrace) {
        _report(error, stackTrace, 'подготовка ${effect.name}');
      }
    }
  }

  @override
  void play(SoundEffect effect, {required double volume}) {
    // Запуски одного эффекта идут по очереди: остановка, громкость и старт не должны перемешаться между собой.
    final previous = _queues[effect] ?? Future<void>.value();
    _queues[effect] = previous.then((_) => _play(effect, volume));
  }

  Future<void> _play(SoundEffect effect, double volume) async {
    try {
      final player = await _player(effect);
      await player.stop();
      await player.setVolume(volume);
      await player.resume();
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace, 'воспроизведение ${effect.name}');
    }
  }

  /// Проигрыватель эффекта; неудавшаяся подготовка не запоминается, следующий запуск попробует снова.
  Future<AudioPlayer> _player(SoundEffect effect) {
    final existing = _players.use(effect);
    if (existing != null) return existing;
    late final Future<AudioPlayer> created;
    created = _create(effect).onError<Object>((error, stackTrace) {
      _players.remove(effect, created);
      Error.throwWithStackTrace(error, stackTrace);
    });
    final evicted = _players.put(effect, created);
    if (evicted != null) unawaited(_close(evicted.key, evicted.value));
    return created;
  }

  Future<void> _close(SoundEffect effect, Future<AudioPlayer> player) async {
    try {
      // Закрывается после запусков, которые уже стоят в очереди этого эффекта.
      await (_queues[effect] ?? Future<void>.value());
      await (await player).dispose();
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace, 'закрытие ${effect.name}');
    }
  }

  Future<AudioPlayer> _create(SoundEffect effect) async {
    await configureGameAudioContext();
    final player = AudioPlayer();
    await player.setPlayerMode(PlayerMode.lowLatency);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(AssetSource('$assetDirectory/${fileName(effect)}'));
    return player;
  }

  void _report(Object error, StackTrace stackTrace, String action) => FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stackTrace, library: 'звук', context: ErrorDescription(action)),
  );
}
