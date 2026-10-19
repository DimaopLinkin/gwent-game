import 'package:gwent/src/features/sound/domain/sound_effect.dart';

/// Вывод звука на устройство.
///
/// Реализация держит проигрыватель и сама решает, как загрузить и сыграть эффект; ошибки воспроизведения она не
/// пробрасывает: звук не должен ломать игру.
abstract interface class SoundOutput {
  /// Заранее готовит эффекты, чтобы первый звук не задерживался.
  Future<void> preload();

  /// Играет [effect] с нуля; [volume] от 0 до 1. Если этот эффект ещё звучит, он начинается заново.
  void play(SoundEffect effect, {required double volume});
}
