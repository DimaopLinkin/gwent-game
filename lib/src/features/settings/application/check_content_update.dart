import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/settings/domain/content_update_result.dart';

/// Сценарий: проверить обновление набора карт.
///
/// Пока источник набора один — встроенный в приложение, — новее него ничего нет: проверка подтверждает, что набор
/// загружен и прошёл все уровни проверки. Когда появится сервер, спрашивать его будет этот сценарий, а экран не
/// изменится. Запись даты проверки остаётся за вызывающим: настройки сохраняет один владелец.
final class CheckContentUpdate {
  /// Создаёт сценарий.
  const CheckContentUpdate(this._loadGameContent, this._clock);

  final LoadGameContent _loadGameContent;
  final Clock _clock;

  /// Проверяет набор.
  Future<ContentUpdateResult> call() async {
    try {
      return switch (await _loadGameContent()) {
        GameContentReady() => ContentUpToDate(_clock.now()),
        GameContentRejected() => const ContentUpdateFailed(),
      };
    } on Object {
      return const ContentUpdateFailed();
    }
  }
}
