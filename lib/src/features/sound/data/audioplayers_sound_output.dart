import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:gwent/src/features/sound/data/effect_voice_pool.dart';
import 'package:gwent/src/features/sound/data/game_audio_context.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';
import 'package:gwent/src/features/sound/domain/sound_output.dart';

/// Звук через `audioplayers` (ADR 0023): проигрыватели эффектов в режиме низкой задержки.
///
/// Файлы лежат в `assets/sfx/` в формате AAC (`.m4a`), один набор на Android и iOS. Проигрыватели живут в
/// [EffectVoicePool]: их число ограничено (на iOS каждый держит свой `AVPlayer`), а повтор эффекта звучит поверх
/// прежнего. Любой вызов плагина, который не ответил за [nativeTimeout], считается сорвавшимся: проигрыватель
/// освобождается, очередь не стоит. Звуковой контекст (чужой звук не прерывается) задаёт `configureGameAudioContext`.
/// Сбой воспроизведения уходит в `FlutterError.reportError`, игра продолжается без звука.
final class AudioplayersSoundOutput implements SoundOutput {
  /// Создаёт вывод; [assetDirectory] — папка с файлами внутри `assets/`, [maxEffects] — сколько эффектов держать
  /// готовыми.
  AudioplayersSoundOutput({
    this.assetDirectory = 'sfx',
    int maxEffects = defaultMaxEffects,
    this.nativeTimeout = const Duration(seconds: 5),
  }) {
    _pool = EffectVoicePool(create: _createVoice, onError: _report, maxEffects: maxEffects);
  }

  /// Сколько эффектов держать готовыми по умолчанию.
  static const int defaultMaxEffects = 12;

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

  /// Сколько ждать ответа плагина на одну команду.
  final Duration nativeTimeout;

  late final EffectVoicePool _pool;

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
    // По одному: десяток проигрывателей, созданных разом, задерживает музыку, которая стартует рядом.
    for (final effect in coreEffects) {
      await _pool.warm(effect);
    }
  }

  @override
  void play(SoundEffect effect, {required double volume}) => _pool.play(effect, volume);

  Future<EffectVoice> _createVoice(SoundEffect effect) async {
    await configureGameAudioContext();
    final player = AudioPlayer()..positionUpdater = null;
    try {
      await (() async {
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource('$assetDirectory/${fileName(effect)}'));
      })().timeout(nativeTimeout);
    } on Object {
      // Не готовый до конца проигрыватель нельзя бросать: за ним стоит нативный `AVPlayer`.
      unawaited(
        player.dispose().then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) => _report(error, stackTrace, 'закрытие ${effect.name}'),
        ),
      );
      rethrow;
    }
    return _AudioplayersVoice(player, nativeTimeout);
  }

  void _report(Object error, StackTrace stackTrace, String action) => FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stackTrace, library: 'звук', context: ErrorDescription(action)),
  );
}

final class _AudioplayersVoice implements EffectVoice {
  _AudioplayersVoice(this._player, this._timeout);

  final AudioPlayer _player;
  final Duration _timeout;

  @override
  Future<void> play(double volume) => (() async {
    await _player.stop();
    await _player.setVolume(volume);
    await _player.resume();
  })().timeout(_timeout);

  @override
  Future<void> dispose() => _player.dispose();
}
