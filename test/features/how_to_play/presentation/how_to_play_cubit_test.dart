import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_play_cubit.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_play_state.dart';
import 'package:gwent_content/gwent_content.dart';

/// Источник, который ломается неожиданным исключением, а не `ContentSourceException`.
final class _BrokenSource implements ContentSource {
  @override
  Future<List<int>> readFile(String path) async => throw StateError('нет доступа');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('набор карт готов: держатель отдаёт его для примеров', () async {
    final cubit = HowToPlayCubit(LoadGameContent(AssetContentSource.basePack(rootBundle)));
    addTearDown(cubit.close);
    expect(cubit.state, isA<HowToPlayLoading>());
    expect(await cubit.stream.first, isA<HowToPlayReady>());
  });

  test('набор карт отклонён: справочник остаётся текстовым', () async {
    final cubit = HowToPlayCubit(LoadGameContent(InMemoryContentSource(const {})));
    addTearDown(cubit.close);
    expect(await cubit.stream.first, isA<HowToPlayUnavailable>());
  });

  test('источник упал неожиданным исключением: справочник остаётся текстовым', () async {
    final cubit = HowToPlayCubit(LoadGameContent(_BrokenSource()));
    addTearDown(cubit.close);
    expect(await cubit.stream.first, isA<HowToPlayUnavailable>());
  });
}
