import 'package:gwent_content/src/validation/validation_issue.dart';

/// Результат разбора файла пакета: модель или список проблем.
sealed class DecodeResult<T> {
  const DecodeResult();
}

/// Файл разобран без проблем.
final class Decoded<T> extends DecodeResult<T> {
  /// Создаёт успешный результат.
  const Decoded(this.value);

  /// Модель файла.
  final T value;
}

/// В файле есть проблемы; модели нет.
final class DecodeFailed<T> extends DecodeResult<T> {
  /// Создаёт неудачный результат.
  const DecodeFailed(this.issues);

  /// Найденные проблемы, не пустой список.
  final List<ValidationIssue> issues;
}
