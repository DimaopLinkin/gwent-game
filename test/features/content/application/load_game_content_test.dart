import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent_content/gwent_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('базовый пакет из ассетов готов к партии', () async {
    final result = await LoadGameContent(AssetContentSource.basePack(rootBundle))();
    if (result case GameContentRejected(:final issues)) fail(issues.join('\n'));
    expect((result as GameContentReady).content.pack.manifest.packId, 'gwent-w3-base');
  });

  test('пакет загружается один раз, повторные вызовы получают тот же результат', () async {
    final source = _CountingSource(AssetContentSource.basePack(rootBundle));
    final load = LoadGameContent(source);
    final first = load();
    final second = load();
    expect(identical(await first, await second), isTrue);
    final reads = source.reads;
    await load();
    expect(source.reads, reads);
  });

  test('пакет не прошёл проверку: проблемы загрузчика', () async {
    final result = await LoadGameContent(InMemoryContentSource(const {}))();
    expect(result, isA<GameContentRejected>());
    expect((result as GameContentRejected).issues.single.code, 'file_unavailable');
  });
}

/// Считает чтения файлов.
final class _CountingSource implements ContentSource {
  _CountingSource(this._inner);

  final ContentSource _inner;
  int reads = 0;

  @override
  Future<List<int>> readFile(String path) {
    reads++;
    return _inner.readFile(path);
  }
}
