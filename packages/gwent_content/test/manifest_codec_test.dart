import 'package:gwent_content/gwent_content.dart';
import 'package:test/test.dart';

void main() {
  Map<String, Object?> manifestJson() => {
    'format_version': 1,
    'pack_id': 'gwent-w3-base',
    'pack_version': 3,
    'min_engine_version': 1,
    'content_hash': 'sha256:${'a' * 64}',
    'locales': ['ru'],
    'files': [
      {'path': 'pack.json', 'sha256': 'a' * 64, 'size': 10},
      {'path': 'strings.ru.json', 'sha256': 'b' * 64, 'size': 20},
    ],
  };

  List<String> codesOf(Object? json) => switch (decodeManifest(json)) {
    Decoded() => const [],
    DecodeFailed(:final issues) => [for (final issue in issues) issue.code],
  };

  test('манифест разбирается и записывается обратно без потерь', () {
    final manifest = (decodeManifest(manifestJson()) as Decoded<Manifest>).value;
    expect(manifest.packVersion, 3);
    expect(manifest.files.map((file) => file.path), ['pack.json', 'strings.ru.json']);
    expect(canonicalJson(encodeManifest(manifest)), canonicalJson(manifestJson()));
  });

  test('файлы пакета это ровно pack.json и строки каждого языка', () {
    final json = manifestJson()
      ..['locales'] = ['ru', 'en']
      ..['files'] = [
        {'path': 'pack.json', 'sha256': 'a' * 64, 'size': 10},
        {'path': 'pack.json', 'sha256': 'a' * 64, 'size': 10},
        {'path': '../secret', 'sha256': 'a' * 64, 'size': 10},
      ];
    expect(codesOf(json), unorderedEquals(['duplicate_file', 'unexpected_file', 'missing_file', 'missing_file']));
  });

  test('запасной язык обязателен', () {
    expect(codesOf(manifestJson()..['locales'] = ['en']), contains('missing_fallback_locale'));
  });

  test('хеши и идентификатор в строгом формате', () {
    final json = manifestJson()
      ..['content_hash'] = 'md5:abc'
      ..['pack_id'] = 'Gwent Base';
    expect(codesOf(json), ['invalid_format', 'invalid_format']);
  });
}
