import 'package:gwent/src/features/sound/domain/music_track.dart';

/// Вывод фоновой музыки на устройство: одна композиция за раз.
///
/// Реализация сама решает, как загрузить и сыграть файл; ошибки воспроизведения она не пробрасывает: музыка не должна
/// ломать игру. Команды выполняются строго в порядке вызова, даже если не дожидаться предыдущей.
abstract interface class MusicOutput {
  /// Композиция доиграла до конца. Остановка и пауза этого события не дают.
  Stream<void> get trackEnded;

  /// Начинает [track] с начала; [volume] от 0 до 1. Прежняя композиция прекращается.
  ///
  /// Возвращает `false`, если композицию запустить не удалось: тогда `trackEnded` не придёт.
  Future<bool> play(MusicTrack track, {required double volume});

  /// Меняет громкость; [volume] от 0 до 1.
  Future<void> setVolume(double volume);

  /// Ставит на паузу.
  Future<void> pause();

  /// Продолжает с места паузы.
  Future<void> resume();
}
