import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/lobby/application/active_network_game.dart';
import 'package:gwent/src/features/lobby/application/discover_network_games.dart';
import 'package:gwent/src/features/lobby/application/host_network_game.dart';
import 'package:gwent/src/features/lobby/application/join_network_game.dart';
import 'package:gwent/src/features/lobby/application/load_network_setup.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent/src/features/replay/application/load_replay.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';

import '../../../support/fakes.dart';
import '../../../support/match_fixtures.dart';
import '../support/fake_game_lobby.dart';

/// Реплей сетевой партии (ADR 0029): хост сохраняет журнал до сброса на реванш, гость кадры своих проекций.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late FakeScheduler scheduler;
  late ActiveNetworkGame hostActive;
  late ActiveNetworkGame guestActive;
  late HostNetworkGame hostGame;
  late JoinNetworkGame joinGame;
  late DiscoverNetworkGames discover;
  late LoadGameContent loader;

  setUpAll(() async => content = await loadBaseContent());

  setUp(() {
    final lobby = FakeGameLobby();
    scheduler = FakeScheduler();
    hostActive = ActiveNetworkGame();
    guestActive = ActiveNetworkGame();
    loader = LoadGameContent(AssetContentSource.basePack(rootBundle));
    final setup = LoadNetworkSetup(
      loader,
      const FakeAppInfo(),
      WatchSettings(InMemorySettingsRepository()),
    );
    hostGame = HostNetworkGame(setup, lobby, hostActive, SecureEntropy(), scheduler, requireAdmission: false);
    joinGame = JoinNetworkGame(setup, lobby, guestActive, scheduler);
    discover = DiscoverNetworkGames(setup, lobby);
  });

  tearDown(() async {
    await hostActive.current?.close();
    await guestActive.current?.close();
  });

  /// Оба выбирают колоды и жмут «Готов», отсчёт проходит, партия начинается.
  Future<void> startMatch(NetworkGame host, NetworkGame guest) async {
    final north = realDeck(content, Faction.northernRealms, id: 'north');
    final monsters = realDeck(content, Faction.monsters, id: 'monsters');
    host.ready(north.toEngineDeck(), deckName: north.name);
    guest.ready(monsters.toEngineDeck());
    await scheduler.elapse(const Duration(seconds: 4));
    await scheduler.flush();
  }

  /// Игра с обоими игроками, партия сыграна: гость сдался, у обоих открыт стол и копятся его обновления.
  Future<({NetworkGame host, NetworkGame guest, MatchSession hostSession, MatchSession guestSession})> finished(
    List<TableUpdate> hostUpdates,
    List<TableUpdate> guestUpdates,
  ) async {
    final host = (await hostGame(gameName: 'Цири', playerName: 'Цири') as NetworkGameOpened).game;
    final found = (await discover().firstWhere((games) => games.isNotEmpty)).single;
    final guest = (await joinGame(found: found.found, playerName: 'Вереск') as NetworkGameOpened).game;
    await scheduler.flush();
    await scheduler.flush();
    await startMatch(host, guest);
    final hostSession = host.openMatch();
    final guestSession = guest.openMatch();
    hostSession.table.updates.listen(hostUpdates.add);
    guestSession.table.updates.listen(guestUpdates.add);
    await scheduler.flush();
    guestSession.table.submit(Seat.two, const Resign());
    await scheduler.flush();
    await scheduler.flush();
    return (host: host, guest: guest, hostSession: hostSession, guestSession: guestSession);
  }

  PlayerView lastView(List<TableUpdate> updates) => updates.whereType<ViewsChanged>().last.views.values.single;

  test('хост записывает журнал с обеими руками, гость кадры своей проекции', () async {
    final hostUpdates = <TableUpdate>[];
    final guestUpdates = <TableUpdate>[];
    final game = await finished(hostUpdates, guestUpdates);

    final hostLog = game.hostSession.recorder!.log! as JournalReplayLog;
    expect(hostLog.perspective, Seat.one);
    expect(hostLog.journal.moves.last, const RecordedMove(Seat.two, Resign()));

    final guestLog = game.guestSession.recorder!.log! as FramesReplayLog;
    expect(guestLog.perspective, Seat.two);
    expect(guestLog.frames.first.view.phase, MatchPhase.redraw);
    expect(guestLog.frames.last.view.phase, MatchPhase.finished);
    expect(guestLog.frames.every((frame) => frame.view.viewer == Seat.two), isTrue);
    expect(guestLog.ruleset.hash, content.pack.manifest.contentHash);
  });

  test('обе записи попадают в историю и открываются реплеем: хост видит обоих, гость только себя', () async {
    final hostUpdates = <TableUpdate>[];
    final guestUpdates = <TableUpdate>[];
    final game = await finished(hostUpdates, guestUpdates);
    final history = InMemoryMatchHistoryRepository();
    final record = RecordFinishedMatch(
      RecordMatch(history, FakeClock(DateTime.utc(2026, 10, 25)), SequentialIdGenerator()),
    );
    final hostRecord = await record(game.hostSession, lastView(hostUpdates));
    final guestRecord = await record(game.guestSession, lastView(guestUpdates));
    final load = LoadReplay(history, loader);

    final hostData = ((await load(hostRecord.id)) as ReplayLoaded).data;
    expect(hostData.timeline.seats, Seat.values.toSet());
    final guestData = ((await load(guestRecord.id)) as ReplayLoaded).data;
    expect(guestData.timeline.seats, {Seat.two});
    expect(guestData.timeline.stepsFor(Seat.two).last.view.outcome, isNotNull);
  });

  test('реванш не портит запись прошлой партии: журнал хоста снят до сброса', () async {
    final hostUpdates = <TableUpdate>[];
    final guestUpdates = <TableUpdate>[];
    final game = await finished(hostUpdates, guestUpdates);
    final before = game.hostSession.recorder!.log!;

    (game.guestSession.table as RematchTable).requestRematch();
    (game.hostSession.table as RematchTable).requestRematch();
    await scheduler.flush();
    await scheduler.flush();
    await startMatch(game.host, game.guest);
    final next = game.host.openMatch();

    expect(game.hostSession.recorder!.log, before);
    expect(next.recorder, isNot(same(game.hostSession.recorder)));
    expect(next.recorder!.log, isNull, reason: 'новая партия ещё не кончилась');
  });
}
