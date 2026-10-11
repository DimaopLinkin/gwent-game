import 'package:gwent_net/src/codec/protocol_exception.dart';

/// Типизированное чтение JSON-объекта собеседника. Любое несоответствие — [MalformedFrame] с путём к полю.
final class JsonReader {
  JsonReader(Object? value, this.path)
    : _map = value is Map<String, Object?> ? value : throw MalformedFrame('$path: ожидался объект');

  final Map<String, Object?> _map;

  /// Путь к объекту для сообщений об ошибке, например `$.p.view.me`.
  final String path;

  bool has(String key) => _map[key] != null;

  int integer(String key) => _typed<int>(key, 'целое число');

  int? optionalInteger(String key) => has(key) ? integer(key) : null;

  String string(String key) => _typed<String>(key, 'строка');

  String? optionalString(String key) => has(key) ? string(key) : null;

  bool boolean(String key) => _typed<bool>(key, 'true или false');

  JsonReader object(String key) => JsonReader(_map[key], '$path.$key');

  /// Вложенный объект или `null`, если поля нет.
  T? optional<T>(String key, T Function(JsonReader reader) read) => has(key) ? read(object(key)) : null;

  /// Список объектов.
  List<T> objects<T>(String key, T Function(JsonReader reader) read) {
    final items = _typed<List<Object?>>(key, 'список');
    return List.unmodifiable([for (var i = 0; i < items.length; i++) read(JsonReader(items[i], '$path.$key[$i]'))]);
  }

  /// Список значений простого типа.
  List<T> values<T>(String key, String expected) {
    final items = _typed<List<Object?>>(key, 'список');
    return List.unmodifiable([
      for (var i = 0; i < items.length; i++)
        items[i] is T ? items[i] as T : throw MalformedFrame('$path.$key[$i]: ожидалось: $expected'),
    ]);
  }

  /// Значение перечисления по имени.
  T enumValue<T extends Enum>(String key, List<T> values) => enumByName(string(key), values, '$path.$key');

  /// Ключи и значения объекта.
  Iterable<(String, JsonReader)> entries(String key) {
    final reader = object(key);
    return reader._map.keys.map((name) => (name, reader.object(name)));
  }

  /// Ключи и целые значения объекта.
  Iterable<(String, int)> integerEntries(String key) {
    final reader = object(key);
    return reader._map.keys.map((name) => (name, reader.integer(name)));
  }

  T _typed<T>(String key, String expected) {
    final value = _map[key];
    if (value is T) return value;
    throw MalformedFrame('$path.$key: ожидалось: $expected');
  }
}

/// Значение перечисления по имени или [MalformedFrame].
T enumByName<T extends Enum>(String name, List<T> values, String path) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw MalformedFrame('$path: неизвестное значение «$name»');
}
