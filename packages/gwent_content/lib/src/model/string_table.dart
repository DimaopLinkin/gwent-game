/// Тексты одного языка: ключ строки → текст (`strings.<locale>.json`).
final class StringTable {
  /// Создаёт таблицу строк языка [locale].
  StringTable({required this.locale, required Map<String, String> entries}) : entries = Map.unmodifiable(entries);

  /// Язык, например `ru`.
  final String locale;

  /// Все строки языка.
  final Map<String, String> entries;

  /// Текст по ключу [key] или `null`.
  String? operator [](String key) => entries[key];
}
