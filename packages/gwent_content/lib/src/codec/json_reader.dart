import 'package:gwent_content/src/json/uuid.dart';
import 'package:gwent_content/src/model/raw_params.dart';
import 'package:gwent_content/src/validation/validation_issue.dart';

/// Читает разобранный JSON одного файла пакета и копит все найденные проблемы схемы, а не падает на первой.
///
/// Методы чтения при ошибке возвращают значение по умолчанию, а проблему записывают в [issues]. Модели,
/// собранные из таких значений, наружу не выходят: результат разбора с проблемами считается неудачным.
final class JsonReader {
  /// Создаёт читателя файла [file].
  JsonReader(this.file);

  /// Имя файла для путей в проблемах, например `pack.json`.
  final String file;

  /// Найденные проблемы.
  final List<ValidationIssue> issues = [];

  /// Записывает проблему по JSON-пути [path].
  void error(String path, String code, String message, {ValidationLevel level = ValidationLevel.schema}) =>
      issues.add(ValidationIssue(level: level, code: code, path: '$file:$path', message: message));

  /// Объект с обязательными полями [required] и необязательными [optional]; других полей быть не должно.
  Map<String, Object?> object(
    Object? value,
    String path, {
    required Set<String> required,
    Set<String> optional = const {},
  }) {
    if (value is! Map<String, Object?>) {
      error(path, 'wrong_type', 'ожидался объект');
      return const {};
    }
    for (final key in required) {
      if (!value.containsKey(key)) error('$path.$key', 'missing_field', 'нет обязательного поля');
    }
    for (final key in value.keys) {
      if (!required.contains(key) && !optional.contains(key)) error('$path.$key', 'unknown_field', 'неизвестное поле');
    }
    return value;
  }

  /// Список.
  List<Object?> list(Object? value, String path) {
    if (value is List<Object?>) return value;
    error(path, 'wrong_type', 'ожидался список');
    return const [];
  }

  /// Непустая строка из поля [key] объекта [json], который лежит по пути [path].
  String string(Map<String, Object?> json, String key, String path) {
    if (!json.containsKey(key)) return '';
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    error('$path.$key', 'wrong_type', 'ожидалась непустая строка');
    return '';
  }

  /// Непустая строка или `null`.
  String? nullableString(Map<String, Object?> json, String key, String path) =>
      json[key] == null ? null : string(json, key, path);

  /// Строка, которая подходит под [pattern]; [description] объясняет формат.
  String matching(Map<String, Object?> json, String key, String path, RegExp pattern, String description) {
    final value = string(json, key, path);
    if (value.isNotEmpty && !pattern.hasMatch(value)) error('$path.$key', 'invalid_format', 'ожидался $description');
    return value;
  }

  /// UUID в каноническом виде.
  String uuid(Map<String, Object?> json, String key, String path) {
    final value = string(json, key, path);
    if (value.isNotEmpty && !isCanonicalUuid(value)) {
      error('$path.$key', 'invalid_uuid', 'ожидался UUID в нижнем регистре');
    }
    return value;
  }

  /// UUID или `null`.
  String? nullableUuid(Map<String, Object?> json, String key, String path) =>
      json[key] == null ? null : uuid(json, key, path);

  /// Целое число не меньше [min].
  int integer(Map<String, Object?> json, String key, String path, {required int min}) {
    if (!json.containsKey(key)) return min;
    final value = json[key];
    if (value is! int) {
      error('$path.$key', 'wrong_type', 'ожидалось целое число');
      return min;
    }
    if (value < min) error('$path.$key', 'out_of_range', 'значение $value меньше $min');
    return value;
  }

  /// Логическое значение.
  bool boolean(Map<String, Object?> json, String key, String path) {
    if (!json.containsKey(key)) return false;
    final value = json[key];
    if (value is bool) return value;
    error('$path.$key', 'wrong_type', 'ожидалось true или false');
    return false;
  }

  /// Параметры эффекта: объект, значения которого `int`, непустые строки или списки непустых строк.
  RawParams params(Map<String, Object?> json, String key, String path) {
    if (!json.containsKey(key)) return const {};
    final value = json[key];
    final at = '$path.$key';
    if (value is! Map<String, Object?>) {
      error(at, 'wrong_type', 'ожидался объект параметров');
      return const {};
    }
    final params = <String, Object>{};
    for (final MapEntry(key: name, :value) in value.entries) {
      switch (value) {
        case int():
          params[name] = value;
        case String() when value.isNotEmpty:
          params[name] = value;
        case List<Object?>() when value.every((item) => item is String && item.isNotEmpty):
          params[name] = List<String>.unmodifiable(value.cast<String>());
        default:
          error('$at.$name', 'wrong_type', 'параметр должен быть целым числом, строкой или списком строк');
      }
    }
    return Map.unmodifiable(params);
  }
}
