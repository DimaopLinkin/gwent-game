import 'package:gwent_content/src/codec/decode_result.dart';
import 'package:gwent_content/src/codec/json_reader.dart';
import 'package:gwent_content/src/json/sha256_digest.dart';
import 'package:gwent_content/src/model/manifest.dart';
import 'package:gwent_content/src/pack_format.dart';

final RegExp _packId = RegExp(r'^[a-z0-9][a-z0-9-]*$');
final RegExp _contentHash = RegExp('^${RegExp.escape(contentHashPrefix)}[0-9a-f]{64}\$');
final RegExp _sha256 = RegExp(r'^[0-9a-f]{64}$');
final RegExp _locale = RegExp(r'^[a-z]{2,3}$');

/// Имя поля с версией формата. Его читают отдельно, до разбора всего манифеста.
const String formatVersionField = 'format_version';

/// Разбирает `manifest.json`. Кроме типов проверяет, что файлы пакета это ровно `pack.json` и файлы строк
/// всех языков из `locales`, а среди языков есть запасной.
DecodeResult<Manifest> decodeManifest(Object? json) {
  final r = JsonReader(manifestFileName);
  final root = r.object(
    json,
    r'$',
    required: const {
      formatVersionField,
      'pack_id',
      'pack_version',
      'min_engine_version',
      'content_hash',
      'locales',
      'files',
    },
  );

  final locales = <String>[];
  if (root.containsKey('locales')) {
    final items = r.list(root['locales'], r'$.locales');
    for (var i = 0; i < items.length; i++) {
      final locale = items[i];
      if (locale is! String || !_locale.hasMatch(locale)) {
        r.error('\$.locales[$i]', 'invalid_format', 'ожидался код языка из 2–3 строчных латинских букв');
      } else if (locales.contains(locale)) {
        r.error('\$.locales[$i]', 'duplicate_locale', 'язык $locale указан дважды');
      } else {
        locales.add(locale);
      }
    }
    if (!locales.contains(fallbackLocale)) {
      r.error(r'$.locales', 'missing_fallback_locale', 'нет запасного языка $fallbackLocale');
    }
  }

  final files = <ManifestFile>[];
  if (root.containsKey('files')) {
    final items = r.list(root['files'], r'$.files');
    for (var i = 0; i < items.length; i++) {
      final path = '\$.files[$i]';
      final file = r.object(items[i], path, required: const {'path', 'sha256', 'size'});
      files.add(
        ManifestFile(
          path: r.string(file, 'path', path),
          sha256: r.matching(file, 'sha256', path, _sha256, '64 символа hex в нижнем регистре'),
          size: r.integer(file, 'size', path, min: 0),
        ),
      );
    }
    final expected = {rulesFileName, for (final locale in locales) stringsFileName(locale)};
    final actual = <String>{};
    for (var i = 0; i < files.length; i++) {
      final filePath = files[i].path;
      if (!expected.contains(filePath)) {
        r.error('\$.files[$i].path', 'unexpected_file', 'файл $filePath не входит в пакет');
      } else if (!actual.add(filePath)) {
        r.error('\$.files[$i].path', 'duplicate_file', 'файл $filePath указан дважды');
      }
    }
    for (final missing in expected.difference(actual)) {
      r.error(r'$.files', 'missing_file', 'нет записи о файле $missing');
    }
  }

  final manifest = Manifest(
    formatVersion: r.integer(root, formatVersionField, r'$', min: 1),
    packId: r.matching(root, 'pack_id', r'$', _packId, 'идентификатор из [a-z0-9-]'),
    packVersion: r.integer(root, 'pack_version', r'$', min: 1),
    minEngineVersion: r.integer(root, 'min_engine_version', r'$', min: 1),
    contentHash: r.matching(root, 'content_hash', r'$', _contentHash, 'хеш вида sha256:<64 hex>'),
    locales: locales,
    files: files,
  );
  return r.issues.isEmpty ? Decoded(manifest) : DecodeFailed(r.issues);
}

/// Записывает манифест в JSON, который [decodeManifest] читает обратно без потерь.
Map<String, Object?> encodeManifest(Manifest manifest) => {
  formatVersionField: manifest.formatVersion,
  'pack_id': manifest.packId,
  'pack_version': manifest.packVersion,
  'min_engine_version': manifest.minEngineVersion,
  'content_hash': manifest.contentHash,
  'locales': manifest.locales,
  'files': [
    for (final file in manifest.files) {'path': file.path, 'sha256': file.sha256, 'size': file.size},
  ],
};
