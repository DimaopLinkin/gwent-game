import 'dart:convert';

import 'package:gwent_content/gwent_content.dart';
import 'package:test/test.dart';

import 'support/sample_pack.dart';

void main() {
  Future<PackLoadResult> load(Map<String, List<int>> files, {EngineCapabilities? engine}) =>
      ContentPackLoader(engine: engine ?? fullEngine).load(InMemoryContentSource(files));

  Future<List<String>> rejectionCodes(Map<String, List<int>> files, {EngineCapabilities? engine}) async =>
      switch (await load(files, engine: engine)) {
        PackLoaded() => const [],
        PackRejected(:final issues) => [for (final issue in issues) issue.code],
      };

  Map<String, Object?> manifestOf(Map<String, List<int>> files) =>
      jsonDecode(utf8.decode(files[manifestFileName]!)) as Map<String, Object?>;

  /// Заменяет файл и обновляет его размер и хеш в манифесте, как сделал бы честный сборщик.
  void replaceFile(Map<String, List<int>> files, String path, List<int> bytes) {
    final manifest = manifestOf(files);
    final entry = (manifest['files']! as List<Object?>).cast<Map<String, Object?>>().firstWhere(
      (f) => f['path'] == path,
    );
    entry
      ..['sha256'] = sha256Hex(bytes)
      ..['size'] = bytes.length;
    files
      ..[path] = bytes
      ..[manifestFileName] = utf8.encode(jsonEncode(manifest));
  }

  test('собранный пакет загружается, тексты берутся по ключу', () async {
    final result = await load(buildSampleFiles());
    final pack = (result as PackLoaded).pack;
    expect(pack.manifest.packId, sampleIdentity.packId);
    expect(pack.rules.squadCards, hasLength(9));
    final hero = pack.rules.squadCardsById[Ids.hero]!;
    expect(pack.text(hero.nameKey), 'текст ${hero.nameKey}');
    expect(pack.text(hero.nameKey, locale: 'en'), 'текст ${hero.nameKey}');
    expect(pack.text('no.such.key'), 'no.such.key');
  });

  test('сборка детерминирована, content_hash это SHA-256 файла pack.json', () {
    final first = buildSampleFiles();
    final second = buildSampleFiles();
    expect(first.keys, second.keys);
    for (final path in first.keys) {
      expect(first[path], second[path], reason: path);
    }
    expect(manifestOf(first)['content_hash'], contentHashOf(first[rulesFileName]!));
  });

  test('порядок записей в таблицах не влияет на пакет', () {
    final reversed = samplePackJson();
    for (final table in ['zones', 'squad_cards', 'squad_abilities']) {
      reversed[table] = rows(reversed, table).reversed.toList();
    }
    expect(buildSampleFiles(rules: reversed)[rulesFileName], buildSampleFiles()[rulesFileName]);
  });

  test('слишком глубокий JSON отклоняется, а не роняет загрузчик', () async {
    final files = buildSampleFiles();
    // jsonDecode такой файл читает, а рекурсивная запись JSON переполнила бы стек.
    final deep = '{"extra":${'[' * 100000}${']' * 100000},${utf8.decode(files[rulesFileName]!).substring(1)}';
    replaceFile(files, rulesFileName, utf8.encode(deep));
    expect(await rejectionCodes(files), ['not_canonicalizable']);
  });

  test('переформатированный pack.json с верным манифестом загружается с тем же content_hash', () async {
    final files = buildSampleFiles();
    final pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(utf8.decode(files[rulesFileName]!)));
    replaceFile(files, rulesFileName, utf8.encode(pretty));
    expect(await load(files), isA<PackLoaded>());
  });

  group('целостность', () {
    test('подменённый файл не совпадает с манифестом по хешу и размеру', () async {
      final files = buildSampleFiles();
      files[rulesFileName] = [...files[rulesFileName]!, 32];
      expect(await rejectionCodes(files), ['size_mismatch', 'hash_mismatch']);
    });

    test('content_hash не совпадает со смыслом правил', () async {
      final files = buildSampleFiles();
      final manifest = manifestOf(files)..['content_hash'] = 'sha256:${'0' * 64}';
      files[manifestFileName] = utf8.encode(jsonEncode(manifest));
      expect(await rejectionCodes(files), ['content_hash_mismatch']);
    });

    test('нет файла', () async {
      final files = buildSampleFiles()..remove(stringsFileName(fallbackLocale));
      expect(await rejectionCodes(files), ['file_unavailable']);
    });

    test('файл не JSON', () async {
      final files = buildSampleFiles();
      replaceFile(files, rulesFileName, utf8.encode('{"zones": '));
      expect(await rejectionCodes(files), ['invalid_json']);
      files[manifestFileName] = [0xff, 0xfe];
      expect(await rejectionCodes(files), ['invalid_json']);
    });
  });

  group('совместимость', () {
    test('другая версия формата отклоняется до разбора манифеста', () async {
      final files = buildSampleFiles();
      files[manifestFileName] = utf8.encode(jsonEncode({'format_version': 99, 'whatever': true}));
      expect(await rejectionCodes(files), ['unsupported_format']);
    });

    test('движок старше нужного', () async {
      const oldEngine = EngineCapabilities(engineVersion: 0, knownEffects: {});
      expect(await rejectionCodes(buildSampleFiles(), engine: oldEngine), ['engine_too_old']);
    });

    test('способность без ссылок (Проворство) движку не нужна', () async {
      final engine = EngineCapabilities(
        engineVersion: 1,
        knownEffects: {for (final effect in EffectKey.values) effect.key}..remove('agile'),
      );
      expect(await load(buildSampleFiles(), engine: engine), isA<PackLoaded>());
    });

    test('эффект, которого нет в движке', () async {
      final engine = EngineCapabilities(
        engineVersion: 1,
        knownEffects: {for (final effect in EffectKey.values) effect.key}..remove('spy'),
      );
      expect(await rejectionCodes(buildSampleFiles(), engine: engine), ['effect_not_supported']);
    });
  });

  test('проблемы схемы и ссылок тоже отклоняют пакет', () async {
    final files = buildSampleFiles();
    final rules = jsonDecode(utf8.decode(files[rulesFileName]!)) as Map<String, Object?>;
    row(rules, 'squad_cards', Ids.hero)['zone_id'] = id(999);
    final bytes = canonicalJsonBytes(rules);
    replaceFile(files, rulesFileName, bytes);
    final manifest = manifestOf(files)..['content_hash'] = contentHashOf(bytes);
    files[manifestFileName] = utf8.encode(jsonEncode(manifest));
    expect(await rejectionCodes(files), ['unknown_reference']);
  });
}
