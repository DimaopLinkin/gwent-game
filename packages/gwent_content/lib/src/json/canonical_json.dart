import 'dart:convert';

/// Значение нельзя записать в каноническом JSON (дробное число или неподдерживаемый тип).
final class CanonicalJsonException implements Exception {
  /// Создаёт исключение с JSON-путём [path] и описанием [message].
  const CanonicalJsonException(this.path, this.message);

  /// Путь до значения, например `$.squad_cards[3].strength`.
  final String path;

  /// Что не так со значением.
  final String message;

  @override
  String toString() => 'CanonicalJsonException($path): $message';
}

/// Канонический JSON пакета: ключи объектов отсортированы по кодовым единицам UTF-16, пробелов нет.
///
/// Строки экранируются как в `jsonEncode`. Поддерживаются `null`, `bool`, целые числа, строки, списки и объекты
/// со строковыми ключами. Дробных чисел в пакете нет: их запись зависит от платформы, а хеш должен совпадать
/// на всех устройствах. Одинаковые по смыслу данные дают одинаковую строку, поэтому от неё считается хеш.
String canonicalJson(Object? value) {
  final out = StringBuffer();
  _write(value, out, r'$');
  return out.toString();
}

/// Канонический JSON в UTF-8.
List<int> canonicalJsonBytes(Object? value) => utf8.encode(canonicalJson(value));

void _write(Object? value, StringBuffer out, String path) {
  switch (value) {
    case null:
      out.write('null');
    case bool():
      out.write(value);
    case int():
      out.write(value);
    case String():
      out.write(jsonEncode(value));
    case List<Object?>():
      out.write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) out.write(',');
        _write(value[i], out, '$path[$i]');
      }
      out.write(']');
    case Map<String, Object?>():
      final keys = value.keys.toList()..sort();
      out.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        out
          ..write(jsonEncode(keys[i]))
          ..write(':');
        _write(value[keys[i]], out, '$path.${keys[i]}');
      }
      out.write('}');
    default:
      throw CanonicalJsonException(path, 'значение типа ${value.runtimeType} нельзя записать в канонический JSON');
  }
}
