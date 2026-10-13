import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/application/ensure_starter_decks.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/menu/application/load_menu.dart';
import 'package:gwent_content/gwent_content.dart';

import '../../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryDeckRepository decks;

  setUp(() => decks = InMemoryDeckRepository());

  LoadMenu scenario(ContentSource source, {String version = '2.3.4'}) {
    final content = LoadGameContent(source);
    final starter = CreateStarterDeck(decks, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator());
    return LoadMenu(
      FakeAppInfo(version),
      content,
      EnsureStarterDecks(decks, GameContentDeckRulesSource(content), starter, DeckSelectionLock()),
    );
  }

  test('набор карт загружен: версии приложения и набора, стартовые колоды подарены', () async {
    final info = await scenario(AssetContentSource.basePack(rootBundle))();

    expect(info.appVersion, '2.3.4');
    expect(info.packVersion, isNotNull);
    expect(info.contentAvailable, isTrue);
    final saved = await decks.watchAll().first;
    expect(saved, isNotEmpty);
    expect({for (final deck in saved) deck.factionId}, hasLength(saved.length), reason: 'по колоде на фракцию');
  });

  test('повторный запуск не плодит колоды', () async {
    final load = scenario(AssetContentSource.basePack(rootBundle));
    await load();
    final first = (await decks.watchAll().first).length;
    await load();
    expect((await decks.watchAll().first).length, first);
  });

  test('набор не прошёл проверку: версия приложения есть, версии набора и колод нет', () async {
    final info = await scenario(InMemoryContentSource(const {}))();

    expect(info.appVersion, '2.3.4');
    expect(info.packVersion, isNull);
    expect(info.contentAvailable, isFalse);
    expect(await decks.watchAll().first, isEmpty, reason: 'без набора карт колоды не из чего собирать');
  });
}
