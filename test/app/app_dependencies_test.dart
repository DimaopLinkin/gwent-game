import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/app/app_dependencies.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';

import '../features/lobby/support/fake_game_lobby.dart';
import '../features/lobby/support/lobby_fakes.dart';
import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('сценарии колод делят одну очередь: одновременные вызовы не задваивают стартовые колоды', () async {
    final decks = InMemoryDeckRepository()..yieldOnRead = true;
    final dependencies = AppDependencies(
      contentSource: AssetContentSource.basePack(rootBundle),
      appInfo: const FakeAppInfo(),
      deckRepository: decks,
      settingsRepository: InMemorySettingsRepository(),
      matchHistoryRepository: InMemoryMatchHistoryRepository(),
      clock: FakeClock(DateTime.utc(2026, 10, 12)),
      idGenerator: SequentialIdGenerator(),
      seedGenerator: FixedSeedGenerator(1),
      gameLobby: FakeGameLobby(),
      onlineLobby: FakeGameLobby(),
      networkAccess: FakeNetworkAccess(),
      soundOutput: RecordingSoundOutput(),
      musicOutput: FakeMusicOutput(),
    );
    final content = (await dependencies.loadGameContent() as GameContentReady).content;
    final factions = content.pack.rules.fractions.where((fraction) => fraction.isDeck).toList();

    await Future.wait([
      for (final faction in factions) dependencies.getActiveDeck(faction.id),
      dependencies.ensureStarterDecks(),
    ]);

    for (final faction in factions) {
      expect(await decks.findByFaction(faction.id), hasLength(1), reason: faction.key);
    }
  });
}
