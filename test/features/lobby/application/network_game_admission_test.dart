import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/lobby/application/active_network_game.dart';
import 'package:gwent/src/features/lobby/application/discover_network_games.dart';
import 'package:gwent/src/features/lobby/application/host_network_game.dart';
import 'package:gwent/src/features/lobby/application/join_network_game.dart';
import 'package:gwent/src/features/lobby/application/load_network_setup.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';

import '../../../support/fakes.dart';
import '../support/fake_game_lobby.dart';

/// Хост сам решает, пускать ли гостя (ADR 0022).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeGameLobby lobby;
  late FakeScheduler scheduler;
  late ActiveNetworkGame hostActive;
  late ActiveNetworkGame guestActive;
  late HostNetworkGame hostGame;
  late JoinNetworkGame joinGame;
  late DiscoverNetworkGames discover;

  setUp(() {
    lobby = FakeGameLobby();
    scheduler = FakeScheduler();
    hostActive = ActiveNetworkGame();
    guestActive = ActiveNetworkGame();
    final setup = LoadNetworkSetup(
      LoadGameContent(AssetContentSource.basePack(rootBundle)),
      const FakeAppInfo(),
      WatchSettings(InMemorySettingsRepository()),
    );
    hostGame = HostNetworkGame(setup, lobby, hostActive, SecureEntropy(), scheduler);
    joinGame = JoinNetworkGame(setup, lobby, guestActive, scheduler);
    discover = DiscoverNetworkGames(setup, lobby);
  });

  tearDown(() async {
    await hostActive.current?.close();
    await guestActive.current?.close();
  });

  Future<(NetworkGame, NetworkGame)> knocked() async {
    final host = ((await hostGame(gameName: 'Цири', playerName: 'Цири')) as NetworkGameOpened).game;
    final found = (await discover().firstWhere((games) => games.isNotEmpty)).single;
    final guest = ((await joinGame(found: found.found, playerName: 'Вереск')) as NetworkGameOpened).game;
    await scheduler.flush();
    await scheduler.flush();
    return (host, guest);
  }

  test('хост пущен сразу, гость ждёт: хост видит имя стучащегося, у гостя пока нет соперника', () async {
    final (host, guest) = await knocked();
    expect(host.room.admitted, isTrue);
    expect(host.room.pendingGuest, 'Вереск');
    expect(host.room.opponent, isNull);
    expect(guest.room.admitted, isFalse);
    expect(guest.room.link, RoomLink.online);
    expect(guest.room.opponent, isNull);
  });

  test('«принять»: у обоих появляется соперник, гость пущен', () async {
    final (host, guest) = await knocked();
    host.admitGuest();
    await scheduler.flush();
    await scheduler.flush();
    expect(host.room.pendingGuest, isNull);
    expect(host.room.opponent?.name, 'Вереск');
    expect(guest.room.admitted, isTrue);
    expect(guest.room.opponent?.name, 'Цири');
  });

  test('«отклонить»: гость получает отказ хоста, у хоста никого нет', () async {
    final (host, guest) = await knocked();
    host.declineGuest();
    await scheduler.flush();
    await scheduler.flush();
    expect(host.room.pendingGuest, isNull);
    expect(host.room.opponent, isNull);
    expect(guest.room.end, const RoomRefused(JoinRefusal.declined));
  });

  test('решение без ожидающего ничего не делает', () async {
    final host = ((await hostGame(gameName: 'Цири', playerName: 'Цири')) as NetworkGameOpened).game;
    await scheduler.flush();
    host
      ..admitGuest()
      ..declineGuest();
    expect(host.room.pendingGuest, isNull);
    expect(host.room.end, isNull);
  });
}
