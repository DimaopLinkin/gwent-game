import 'package:gwent_content/src/model/content_pack.dart';
import 'package:gwent_content/src/validation/validation_issue.dart';

/// Итог загрузки пакета.
sealed class PackLoadResult {
  const PackLoadResult();
}

/// Пакет прошёл все уровни проверки, его можно активировать.
final class PackLoaded extends PackLoadResult {
  /// Создаёт успешный итог.
  const PackLoaded(this.pack);

  /// Проверенный пакет.
  final ContentPack pack;
}

/// Пакет отклонён: активной остаётся прежняя версия.
final class PackRejected extends PackLoadResult {
  /// Создаёт итог с проблемами [issues].
  const PackRejected(this.issues);

  /// Проблемы шага, на котором проверка остановилась. Не пустой список; уровни внутри шага могут быть разными
  /// (например, неизвестный эффект находится при разборе схемы, но относится к совместимости).
  final List<ValidationIssue> issues;
}
