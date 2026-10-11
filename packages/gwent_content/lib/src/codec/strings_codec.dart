import 'package:gwent_content/src/codec/decode_result.dart';
import 'package:gwent_content/src/codec/json_reader.dart';
import 'package:gwent_content/src/model/string_table.dart';
import 'package:gwent_content/src/pack_format.dart';

/// Разбирает `strings.<locale>.json`: плоский объект «ключ строки → непустой текст».
DecodeResult<StringTable> decodeStrings(String locale, Object? json) {
  final r = JsonReader(stringsFileName(locale));
  final entries = <String, String>{};
  if (json is Map<String, Object?>) {
    for (final MapEntry(:key, :value) in json.entries) {
      if (value is String && value.isNotEmpty) {
        entries[key] = value;
      } else {
        r.error('\$["$key"]', 'wrong_type', 'текст должен быть непустой строкой');
      }
    }
  } else {
    r.error(r'$', 'wrong_type', 'ожидался объект «ключ → текст»');
  }
  return r.issues.isEmpty ? Decoded(StringTable(locale: locale, entries: entries)) : DecodeFailed(r.issues);
}

/// Записывает строки в JSON, который [decodeStrings] читает обратно без потерь.
Map<String, Object?> encodeStrings(StringTable table) => Map.of(table.entries);
