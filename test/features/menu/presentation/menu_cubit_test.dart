import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/domain/app_info.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/application/ensure_starter_decks.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/menu/application/load_menu.dart';
import 'package:gwent/src/features/menu/presentation/menu_cubit.dart';
import 'package:gwent/src/features/menu/presentation/menu_state.dart';
import 'package:gwent_content/gwent_content.dart';

import '../../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryDeckRepository decks;

  setUp(() => decks = InMemoryDeckRepository());

  LoadMenu loadMenu(ContentSource source) {
    final content = LoadGameContent(source);
    final starter = CreateStarterDeck(decks, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator());
    return LoadMenu(
      const FakeAppInfo('1.2.3'),
      content,
      EnsureStarterDecks(decks, GameContentDeckRulesSource(content), starter, DeckSelectionLock()),
    );
  }

  MenuCubit newCubit(ContentSource source, {Duration minSplash = Duration.zero}) {
    final cubit = MenuCubit(loadMenu(source), WatchDecks(decks), minSplash: minSplash);
    addTearDown(cubit.close);
    return cubit;
  }

  Future<MenuReady> ready(MenuCubit cubit) async =>
      await cubit.stream.firstWhere((state) => state is MenuReady) as MenuReady;

  test('сначала заставка, потом меню; с набором и колодами играть можно', () async {
    final cubit = newCubit(AssetContentSource.basePack(rootBundle));
    expect(cubit.state, isA<MenuLoading>());

    final state = await ready(cubit);
    expect(state.appVersion, '1.2.3');
    expect(state.packVersion, isNotNull);
    expect(state.contentAvailable, isTrue);
    expect(state.hasDeck, isTrue);
    expect(state.canPlay, isTrue);
  });

  test('заставка держится не меньше заданного времени', () async {
    final cubit = newCubit(AssetContentSource.basePack(rootBundle), minSplash: const Duration(milliseconds: 400));
    final started = Stopwatch()..start();
    await ready(cubit);
    expect(started.elapsedMilliseconds, greaterThanOrEqualTo(380));
  });

  test('набор карт не загрузился: меню готово, но играть нельзя', () async {
    final cubit = newCubit(InMemoryContentSource(const {}));

    final state = await ready(cubit);
    expect(state.contentAvailable, isFalse);
    expect(state.packVersion, isNull);
    expect(state.appVersion, '1.2.3');
    expect(state.canPlay, isFalse);
  });

  test('сбой подготовки меню не оставляет заставку навсегда', () async {
    final content = LoadGameContent(AssetContentSource.basePack(rootBundle));
    final failing = LoadMenu(
      _ThrowingAppInfo(),
      content,
      EnsureStarterDecks(
        decks,
        GameContentDeckRulesSource(content),
        CreateStarterDeck(decks, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator()),
        DeckSelectionLock(),
      ),
    );
    final cubit = MenuCubit(failing, WatchDecks(decks), minSplash: Duration.zero);
    addTearDown(cubit.close);

    final state = await ready(cubit);
    expect(state.contentAvailable, isFalse);
    expect(state.appVersion, isNull);
    expect(state.canPlay, isFalse);
  });

  test('удалили последнюю колоду: играть нельзя, появилась — можно', () async {
    final cubit = newCubit(AssetContentSource.basePack(rootBundle));
    final first = await ready(cubit);
    expect(first.canPlay, isTrue);

    final saved = await decks.watchAll().first;
    final emptied = cubit.stream.firstWhere((state) => state is MenuReady && !state.hasDeck);
    for (final deck in saved) {
      await decks.delete(deck.id);
    }
    expect(((await emptied) as MenuReady).canPlay, isFalse);

    final restored = cubit.stream.firstWhere((state) => state is MenuReady && state.hasDeck);
    await decks.save(saved.first);
    expect(((await restored) as MenuReady).canPlay, isTrue);
  });

  test('ошибка чтения колод: играть нельзя, меню остаётся', () async {
    decks.watchError = Exception('база недоступна');
    final cubit = newCubit(AssetContentSource.basePack(rootBundle));

    final state = await ready(cubit);
    expect(state.hasDeck, isFalse);
    expect(state.canPlay, isFalse);
  });

  test('меню закрыли во время заставки: ничего не падает', () async {
    final cubit = MenuCubit(
      loadMenu(AssetContentSource.basePack(rootBundle)),
      WatchDecks(decks),
      minSplash: const Duration(milliseconds: 200),
    );
    await cubit.close();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(cubit.isClosed, isTrue);
  });

  test('состояния сравниваются по значению', () {
    const a = MenuReady(appVersion: '1', packVersion: 2, contentAvailable: true, hasDeck: true);
    const b = MenuReady(appVersion: '1', packVersion: 2, contentAvailable: true, hasDeck: true);
    const c = MenuReady(appVersion: '1', packVersion: 2, contentAvailable: true, hasDeck: false);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });
}

final class _ThrowingAppInfo implements AppInfo {
  @override
  Future<String> version() => Future.error(StateError('нет данных'));
}
