import 'dart:async';

/// Пауза партии на этом устройстве: пока она включена, соперник без человека (бот) не думает и не ходит.
///
/// Общая для стола и агентов: стол включает её по просьбе экрана ([setPaused]), агент отсчитывает паузу на размышление
/// через [delay], и время, проведённое на паузе, в этот отсчёт не входит.
final class MatchPause {
  /// Создаёт паузу; [tick] — шаг, которым [delay] проверяет, не включилась ли пауза посреди ожидания.
  MatchPause({this.tick = const Duration(milliseconds: 50)});

  /// Шаг отсчёта в [delay].
  final Duration tick;

  Completer<void>? _resumed;

  /// Пауза включена.
  bool get isPaused => _resumed != null;

  /// Включает ([paused] = `true`) или выключает паузу.
  void setPaused({required bool paused}) {
    if (paused) {
      _resumed ??= Completer<void>();
    } else {
      final resumed = _resumed;
      _resumed = null;
      resumed?.complete();
    }
  }

  /// Завершается сразу, если паузы нет, а иначе — когда она закончится.
  Future<void> untilResumed() async {
    for (var resumed = _resumed; resumed != null; resumed = _resumed) {
      await resumed.future;
    }
  }

  /// Ждёт [duration], не считая время на паузе: если пауза включилась посреди ожидания, отсчёт встаёт и
  /// продолжается после неё с того же места (с точностью до [tick]).
  Future<void> delay(Duration duration) async {
    var remaining = duration;
    while (remaining > Duration.zero) {
      if (isPaused) {
        await untilResumed();
        continue;
      }
      final slice = remaining < tick ? remaining : tick;
      await Future<void>.delayed(slice);
      if (!isPaused) remaining -= slice;
    }
  }
}
