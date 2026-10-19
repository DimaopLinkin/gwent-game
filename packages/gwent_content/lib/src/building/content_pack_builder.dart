import 'package:gwent_content/src/codec/manifest_codec.dart';
import 'package:gwent_content/src/codec/rules_codec.dart';
import 'package:gwent_content/src/codec/strings_codec.dart';
import 'package:gwent_content/src/json/canonical_json.dart';
import 'package:gwent_content/src/json/sha256_digest.dart';
import 'package:gwent_content/src/model/manifest.dart';
import 'package:gwent_content/src/model/pack_rules.dart';
import 'package:gwent_content/src/model/string_table.dart';
import 'package:gwent_content/src/pack_format.dart';

/// Кто такой пакет: идентификатор набора и версии.
final class PackIdentity {
  /// Создаёт описание пакета.
  const PackIdentity({required this.packId, required this.packVersion, required this.minEngineVersion});

  /// Идентификатор набора, например `gwent-w3-base`.
  final String packId;

  /// Версия набора.
  final int packVersion;

  /// Минимальная версия движка.
  final int minEngineVersion;
}

/// Собранный пакет: манифест и байты всех файлов, включая `manifest.json`.
final class BuiltContentPack {
  /// Создаёт собранный пакет.
  BuiltContentPack({required this.manifest, required Map<String, List<int>> files}) : files = Map.unmodifiable(files);

  /// Манифест.
  final Manifest manifest;

  /// Путь относительно папки пакета → байты.
  final Map<String, List<int>> files;
}

/// Собирает файлы пакета из правил [rules] и строк [strings] (язык → таблица).
///
/// Записи каждой таблицы сортируются по UUID, а все файлы пишутся каноническим JSON, поэтому одинаковые данные
/// в любом порядке дают побайтово одинаковый пакет, а `content_hash` совпадает с SHA-256 файла `pack.json`.
/// Проверку содержимого сборка не делает: её делает загрузчик над результатом.
BuiltContentPack buildContentPack({
  required PackIdentity identity,
  required PackRules rules,
  required Map<String, StringTable> strings,
}) {
  final rulesBytes = canonicalJsonBytes(_sortedById(encodeRules(rules)));
  final locales = strings.keys.toList()..sort();
  final files = <String, List<int>>{
    rulesFileName: rulesBytes,
    for (final locale in locales) stringsFileName(locale): canonicalJsonBytes(encodeStrings(strings[locale]!)),
  };
  final paths = files.keys.toList()..sort();
  final manifest = Manifest(
    formatVersion: packFormatVersion,
    packId: identity.packId,
    packVersion: identity.packVersion,
    minEngineVersion: identity.minEngineVersion,
    contentHash: contentHashOf(rulesBytes),
    locales: locales,
    files: [
      for (final path in paths) ManifestFile(path: path, sha256: sha256Hex(files[path]!), size: files[path]!.length),
    ],
  );
  return BuiltContentPack(
    manifest: manifest,
    files: {...files, manifestFileName: canonicalJsonBytes(encodeManifest(manifest))},
  );
}

/// Таблицы правил с записями, отсортированными по `id`.
Map<String, Object?> _sortedById(Map<String, Object?> rulesJson) => {
  for (final MapEntry(:key, :value) in rulesJson.entries)
    key: value is List<Object?>
        ? ([...value.cast<Map<String, Object?>>()]..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String)))
        : value,
};
