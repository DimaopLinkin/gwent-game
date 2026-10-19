import 'package:audioplayers/audioplayers.dart';

/// Звуковой контекст игры для всех проигрывателей приложения (ADR 0023): эффекты и музыка не забирают звуковой фокус
/// у других приложений (Android) и смешиваются с их звуком, подчиняясь переключателю «Без звука» (iOS, сессия `ambient`).
///
/// Контекст ставится один раз за процесс; все вызовы ждут одного и того же результата. Неудача не запоминается: следующее
/// обращение пробует ещё раз.
Future<void> configureGameAudioContext() async {
  final pending = _configured;
  if (pending != null) return pending;
  final run = _configured = AudioPlayer.global.setAudioContext(
    AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    ),
  );
  try {
    await run;
  } on Object {
    if (identical(_configured, run)) _configured = null;
    rethrow;
  }
}

Future<void>? _configured;
