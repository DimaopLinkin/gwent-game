import 'dart:async';
import 'dart:math';

import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/sound/domain/music_output.dart';
import 'package:gwent/src/features/sound/domain/music_track.dart';

/// Сценарий: фоновая музыка приложения (ADR 0023).
///
/// После [start] композиции идут по кругу в случайном порядке (каждая звучит раз за круг, одна и та же не звучит два
/// раза подряд). Громкость берётся из настроек и меняется на лету; при нуле музыка стоит на паузе и не тратит
/// батарею, а при возврате громкости продолжается с того же места. Приложение, ушедшее в фон, ставит музыку на паузу
/// через [pause] и возвращает через [resume]. Сценарий живёт столько же, сколько приложение.
final class BackgroundMusic {
  /// Создаёт сценарий над [_output]; [random] выбирает порядок композиций.
  BackgroundMusic(this._output, WatchSettings watchSettings, this._random) {
    _settings = watchSettings().listen(_onSettings, onError: _ignoreSettingsError);
    _ended = _output.trackEnded.listen((_) => unawaited(_playNext()));
  }

  final MusicOutput _output;
  final Random _random;
  late final StreamSubscription<AppSettings> _settings;
  late final StreamSubscription<void> _ended;

  final List<MusicTrack> _queue = [];
  MusicTrack? _last;
  int _volume = AppSettings.defaultMusicVolume;
  bool _started = false;
  bool _paused = false;

  /// Композиция загружена в проигрыватель (играет или стоит на паузе).
  bool _loaded = false;

  /// Проигрыватель сейчас играет.
  bool _playing = false;

  /// Музыка должна звучать: запущена, приложение на виду и громкость не нулевая.
  bool get _audible => _started && !_paused && _volume > 0;

  double get _level => _volume / AppSettings.maxVolume;

  /// Запускает музыку; повторный вызов ничего не меняет.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _sync();
  }

  /// Ставит музыку на паузу (приложение ушло в фон).
  Future<void> pause() async {
    _paused = true;
    await _sync();
  }

  /// Продолжает музыку (приложение вернулось).
  Future<void> resume() async {
    _paused = false;
    await _sync();
  }

  /// Перестаёт следить за настройками и проигрывателем.
  Future<void> dispose() async {
    await _settings.cancel();
    await _ended.cancel();
  }

  void _onSettings(AppSettings settings) {
    if (settings.musicVolume == _volume) return;
    _volume = settings.musicVolume;
    unawaited(_sync());
  }

  // Настройки не читаются: музыка остаётся на последней известной громкости.
  void _ignoreSettingsError(Object error) {}

  Future<void> _sync() async {
    if (!_audible) {
      if (_playing) {
        _playing = false;
        await _output.pause();
      }
      return;
    }
    if (!_loaded) {
      await _playNext();
    } else if (!_playing) {
      _playing = true;
      await _output.setVolume(_level);
      await _output.resume();
    } else {
      await _output.setVolume(_level);
    }
  }

  Future<void> _playNext() async {
    _loaded = false;
    _playing = false;
    if (!_audible) return;
    final track = _nextTrack();
    _loaded = true;
    _playing = true;
    await _output.play(track, volume: _level);
  }

  MusicTrack _nextTrack() {
    if (_queue.isEmpty) {
      _queue.addAll(MusicTrack.values.toList()..shuffle(_random));
      // Новый круг не начинается с композиции, которой закончился прошлый.
      if (_queue.length > 1 && _queue.first == _last) {
        _queue.add(_queue.removeAt(0));
      }
    }
    return _last = _queue.removeAt(0);
  }
}
