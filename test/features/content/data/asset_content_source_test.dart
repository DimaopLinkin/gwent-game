import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent_content/gwent_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('читает файл пакета из своей папки в ассетах', () async {
    final source = AssetContentSource(
      bundle: _MemoryBundle({'packs/a/manifest.json': utf8.encode('{}')}),
      root: 'packs/a',
    );
    expect(utf8.decode(await source.readFile(manifestFileName)), '{}');
  });

  test('нет файла: ContentSourceException с путём внутри пакета', () async {
    final source = AssetContentSource(bundle: _MemoryBundle(const {}), root: 'packs/a');
    await expectLater(
      source.readFile(manifestFileName),
      throwsA(isA<ContentSourceException>().having((e) => e.path, 'path', manifestFileName)),
    );
  });

  test('базовый пакет из ассетов приложения проходит все уровни проверки', () async {
    // Движок пока не реализует эффекты (`knownEffects` пуст), поэтому здесь движок, знающий весь формат.
    // Сопоставление с движком появится отдельной задачей.
    final engine = EngineCapabilities(
      engineVersion: 1,
      knownEffects: {for (final effect in EffectKey.values) effect.key},
    );
    final result = await ContentPackLoader(engine: engine).load(AssetContentSource.basePack(rootBundle));
    if (result case PackRejected(:final issues)) fail(issues.join('\n'));
    final pack = (result as PackLoaded).pack;
    expect(pack.manifest.packId, 'gwent-w3-base');
    expect(pack.rules.squadCards, hasLength(153));
  });
}

/// Ассеты в памяти: путь → байты.
final class _MemoryBundle extends CachingAssetBundle {
  _MemoryBundle(this.files);

  final Map<String, List<int>> files;

  @override
  Future<ByteData> load(String key) async {
    final bytes = files[key];
    if (bytes == null) throw FlutterError('Unable to load asset: "$key".');
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}
