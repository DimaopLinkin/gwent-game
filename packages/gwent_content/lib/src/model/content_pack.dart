import 'package:gwent_content/src/model/manifest.dart';
import 'package:gwent_content/src/model/pack_rules.dart';
import 'package:gwent_content/src/model/string_table.dart';
import 'package:gwent_content/src/pack_format.dart';

/// Загруженный и проверенный пакет контента: манифест, таблицы правил и строки всех языков.
final class ContentPack {
  /// Создаёт пакет.
  ContentPack({required this.manifest, required this.rules, required Map<String, StringTable> strings})
    : strings = Map.unmodifiable(strings);

  /// Манифест.
  final Manifest manifest;

  /// Таблицы правил.
  final PackRules rules;

  /// Строки по языку.
  final Map<String, StringTable> strings;

  /// Текст по ключу [key] на языке [locale]; если его нет, то на запасном языке, а если нет и там, сам ключ.
  ///
  /// У проверенного пакета все ключи есть на всех языках, поэтому запасные варианты нужны только для языков,
  /// поставленных отдельно от правил.
  String text(String key, {String locale = fallbackLocale}) =>
      strings[locale]?[key] ?? strings[fallbackLocale]?[key] ?? key;
}
