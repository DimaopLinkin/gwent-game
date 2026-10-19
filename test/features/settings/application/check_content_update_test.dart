import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/settings/application/check_content_update.dart';
import 'package:gwent/src/features/settings/domain/content_update_result.dart';
import 'package:gwent_content/gwent_content.dart';

import '../../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 18, 10);

  test('набор загружен и проверен: он актуален, дата проверки берётся из часов', () async {
    final check = CheckContentUpdate(LoadGameContent(AssetContentSource.basePack(rootBundle)), FakeClock(now));

    final result = await check();

    expect(result, isA<ContentUpToDate>().having((r) => r.checkedAt, 'checkedAt', now));
  });

  test('набор не прошёл проверку: проверить не удалось', () async {
    final check = CheckContentUpdate(LoadGameContent(InMemoryContentSource(const {})), FakeClock(now));

    expect(await check(), isA<ContentUpdateFailed>());
  });

  test('сбой источника тоже не удалось проверить, а не падение', () async {
    final check = CheckContentUpdate(LoadGameContent(_ThrowingSource()), FakeClock(now));

    expect(await check(), isA<ContentUpdateFailed>());
  });
}

final class _ThrowingSource implements ContentSource {
  @override
  Future<List<int>> readFile(String path) => Future.error(StateError('нет доступа'));
}
