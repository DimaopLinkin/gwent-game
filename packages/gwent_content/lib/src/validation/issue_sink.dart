import 'package:gwent_content/src/pack_format.dart';
import 'package:gwent_content/src/validation/validation_issue.dart';

/// Копит проблемы одного уровня проверки с путями внутри `pack.json`.
final class IssueSink {
  /// Создаёт накопитель проблем уровня [level].
  IssueSink(this.level);

  /// Уровень всех проблем этого накопителя.
  final ValidationLevel level;

  /// Найденные проблемы.
  final List<ValidationIssue> issues = [];

  /// Записывает проблему по JSON-пути [path] в файле [file].
  void add(String path, String code, String message, {String file = rulesFileName}) =>
      issues.add(ValidationIssue(level: level, code: code, path: '$file:$path', message: message));
}
