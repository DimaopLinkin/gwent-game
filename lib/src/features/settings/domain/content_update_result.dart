import 'package:meta/meta.dart';

/// Итог проверки обновления набора карт.
sealed class ContentUpdateResult {
  const ContentUpdateResult();
}

/// Набор карт актуален: новее нет.
@immutable
final class ContentUpToDate extends ContentUpdateResult {
  /// Создаёт итог; [checkedAt] — момент проверки (UTC).
  const ContentUpToDate(this.checkedAt);

  /// Когда проверка закончилась.
  final DateTime checkedAt;
}

/// Проверить не удалось: текущий набор не загрузился или не прошёл проверку.
final class ContentUpdateFailed extends ContentUpdateResult {
  /// Создаёт итог.
  const ContentUpdateFailed();
}
