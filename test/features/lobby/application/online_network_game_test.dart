import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/lobby/application/active_network_game.dart';
import 'package:gwent/src/features/lobby/application/host_network_game.dart';
import 'package:gwent/src/features/lobby/application/join_network_game.dart';
import 'package:gwent/src/features/lobby/application/link_timings.dart';
import 'package:gwent/src/features/lobby/application/load_network_setup.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/data/online/online_lobby.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';

import '../../../support/fakes.dart';
import '../../../support/match_fixtures.dart';
import '../support/fake_online_server.dart';

/// Партия через интернет: настоящие `MatchHost`, `MatchClient` и `NetworkGame` над `OnlineLobby` и сервером в памяти.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late FakeClock clock;
  late FakeScheduler scheduler;
  late FakeOnlineServer server;
  late FakeOnlineRooms hostRooms;
  late FakeOnlineRooms guestRooms;
  late ActiveNetworkGame hostActive;
  late ActiveNetworkGame guestActive;
  late HostNetworkGame hostGame;
  late JoinNetworkGame joinGame;
  late LoadNetworkSetup setup;

  JoinNetworkGame joinOn(FakeOnlineRooms rooms, ActiveNetworkGame active) => JoinNetworkGame(
    setup,
    OnlineLobby(rooms: rooms, scheduler: scheduler, clock: clock),
    active,
    scheduler,
    timings: LinkTimings.internet,
  );

  setUpAll(() async => content = await loadBaseContent());

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 10, 20, 12));
    scheduler = FakeScheduler();
    server = FakeOnlineServer(clock);
    hostRooms = server.phone('host');
    guestRooms = server.phone('guest');
    hostActive = ActiveNetworkGame();
    guestActive = ActiveNetworkGame();
    setup = LoadNetworkSetup(
      LoadGameContent(AssetContentSource.basePack(rootBundle)),
      const FakeAppInfo(),
      WatchSettings(InMemorySettingsRepository()),
    );
    hostGame = HostNetworkGame(
      setup,
      OnlineLobby(rooms: hostRooms, scheduler: scheduler, clock: clock),
      hostActive,
      SecureEntropy(),
      scheduler,
      timings: LinkTimings.internet,
    );
    joinGame = joinOn(guestRooms, guestActive);
  });

  tearDown(() async {
    await hostActive.current?.close();
    await guestActive.current?.close();
  });

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await scheduler.flush();
    }
  }

  Future<NetworkGame> hostOpened() async {
    final result = await hostGame(gameName: 'Цири', playerName: 'Цири');
    return (result as NetworkGameOpened).game;
  }

  Future<OnlineAddress> codeOf(NetworkGame host) async {
    final address = await host.address();
    return address is OnlineAddress ? address : throw StateError('Адрес не онлайн: $address');
  }

  /// Гость входит по коду; join ждёт ответа хоста, поэтому время идёт, пока он не выдаст место.
  Future<NetworkOpenResult> join(
    NetworkGame host, {
    String name = 'Вереск',
    JoinNetworkGame? by,
    GameAddress? address,
  }) async {
    final pending = (by ?? joinGame).byAddress(address ?? await codeOf(host), playerName: name);
    final done = Completer<NetworkOpenResult>();
    unawaited(pending.then(done.complete));
    while (!done.isCompleted) {
      await scheduler.elapse(const Duration(milliseconds: 100));
    }
    return done.future;
  }

  /// Хост и гость в лобби, хост пустил гостя.
  Future<(NetworkGame, NetworkGame)> connected() async {
    final host = await hostOpened();
    final guest = (await join(host) as NetworkGameOpened).game;
    await settle();
    host.admitGuest();
    await settle();
    return (host, guest);
  }

  test('хост получает код комнаты, гость входит по нему, хост пускает гостя: у каждого есть соперник', () async {
    final host = await hostOpened();
    final address = await codeOf(host);
    expect(address.code.value, hasLength(RoomCode.length));

    final guest = (await join(host) as NetworkGameOpened).game;
    await settle();
    expect(host.room.pendingGuest, 'Вереск');
    expect(guest.room.admitted, isFalse);
    host.admitGuest();
    await settle();

    expect(host.room.opponent?.name, 'Вереск');
    expect(guest.room.opponent?.name, 'Цири');
    expect(guest.room.admitted, isTrue);
    expect(guest.room.link, RoomLink.online);
    expect(server.rooms.values.single.guestUid, 'guest');
  });

  test('код вводится в любом виде: строчными, с дефисом', () async {
    final host = await hostOpened();
    final code = (await codeOf(host)).code.formatted.toLowerCase();

    final result = await join(host, address: OnlineAddress(RoomCode.tryParse(code)!));

    expect(result, isA<NetworkGameOpened>());
  });

  test('хост отказал гостю: гость получает отказ, у хоста новый код, старый не работает', () async {
    final host = await hostOpened();
    final oldCode = (await codeOf(host)).code;
    final guest = (await join(host) as NetworkGameOpened).game;
    await settle();
    expect(host.room.pendingGuest, isNotNull);

    host.declineGuest();
    await settle();
    await settle();

    expect(guest.room.end, const RoomRefused(JoinRefusal.declined));
    final newCode = (await codeOf(host)).code;
    expect(newCode, isNot(oldCode));
    final second = await join(host, name: 'Эмиель', by: joinOn(server.phone('second'), ActiveNetworkGame()));
    expect(second, isA<NetworkGameOpened>());
    await settle();
    expect(host.room.pendingGuest, 'Эмиель');

    final third = await join(
      host,
      by: joinOn(server.phone('third'), ActiveNetworkGame()),
      address: OnlineAddress(oldCode),
    );
    expect(third, isA<NetworkRoomRefused>().having((refused) => refused.failure, 'failure', LobbyFailure.codeNotFound));
  });

  test('гость ушёл из лобби: место освободилось, у хоста новый код, и другой гость входит', () async {
    final (host, guest) = await connected();
    final oldCode = (await codeOf(host)).code;

    await guest.leave();
    await settle();
    await settle();

    expect(host.room.opponent, isNull);
    final newCode = (await codeOf(host)).code;
    expect(newCode, isNot(oldCode));
    final second = await join(host, name: 'Эмиель', by: joinOn(server.phone('second'), ActiveNetworkGame()));
    expect(second, isA<NetworkGameOpened>());
  });

  test('второй гость по занятому коду получает отказ с причиной', () async {
    final (host, _) = await connected();

    final result = await join(host, by: joinOn(server.phone('second'), ActiveNetworkGame()));

    expect(result, isA<NetworkRoomRefused>().having((refused) => refused.failure, 'failure', LobbyFailure.roomFull));
    expect(host.room.opponent?.name, 'Вереск');
  });

  test('неверный код, свой код и недоступный сервис называют причину', () async {
    final host = await hostOpened();

    final wrong = await join(host, address: OnlineAddress(RoomCode.tryParse('ABCDEF')!));
    expect(wrong, isA<NetworkRoomRefused>().having((refused) => refused.failure, 'failure', LobbyFailure.codeNotFound));

    final own = await join(host, by: joinOn(hostRooms, ActiveNetworkGame()));
    expect(own, isA<NetworkRoomRefused>().having((refused) => refused.failure, 'failure', LobbyFailure.ownRoom));

    server.offline = true;
    expect(await join(host), isA<NetworkUnavailable>());
  });

  test('сервер не даёт создать комнату: итог называет причину, сервис недоступен: общий отказ', () async {
    hostRooms.createFailure = LobbyFailure.tooManyRooms;
    final tooMany = await hostGame(gameName: 'Цири', playerName: 'Цири');
    expect(
      tooMany,
      isA<NetworkRoomRefused>().having((refused) => refused.failure, 'failure', LobbyFailure.tooManyRooms),
    );

    hostRooms.createFailure = null;
    server.offline = true;
    expect(await hostGame(gameName: 'Цири', playerName: 'Цири'), isA<NetworkUnavailable>());
    expect(hostActive.current, isNull);
  });

  test('хост закрыл лобби: гость узнаёт об этом, комната на сервере закрыта', () async {
    final (host, guest) = await connected();

    await host.leave();
    await settle();

    expect(guest.room.end, const RoomHostClosed());
    expect(server.rooms.values.single.closedAt, isNotNull);
  });

  test(
    'связь гостя оборвалась и вернулась: он возвращается на своё место по токену, не занимая комнату заново',
    () async {
      final (host, guest) = await connected();
      final hostChannel = server.rooms.values.single.channels.first;
      final guestChannel = server.rooms.values.single.channels.last;
      hostChannel.up = false;
      guestChannel.up = false;

      await scheduler.elapse(LinkTimings.internet.linkTimeout + const Duration(seconds: 1));
      await settle();
      expect(guest.room.link, RoomLink.lost);
      expect(host.room.opponent?.online, isFalse);

      hostChannel.up = true;
      guestChannel.up = true;
      await scheduler.elapse(LinkTimings.internet.pingInterval * 3);
      await settle();

      expect(guest.room.link, RoomLink.online);
      expect(host.room.opponent?.online, isTrue);
      expect(guest.room.opponent?.name, 'Цири');
      expect(guestRooms.calls.where((call) => call.startsWith('join:')), hasLength(1));
      expect(server.rooms.values.where(server.isAlive), hasLength(1));
    },
  );

  test('хост молчит дольше окна возвращения: гость сдаётся, потеряв связь', () async {
    final (host, guest) = await connected();
    final room = server.rooms.values.single;
    for (final channel in room.channels) {
      channel.up = false;
    }

    await scheduler.elapse(LinkTimings.internet.reconnectWindow + LinkTimings.internet.linkTimeout);
    await settle();

    expect(guest.room.end, const RoomConnectionLost());
    expect(host.room.opponent?.online, isNot(true));
  });

  test('оба готовы: идёт отсчёт и партия начинается через интернет', () async {
    final (host, guest) = await connected();
    final north = realDeck(content, Faction.northernRealms, id: 'north');
    final monsters = realDeck(content, Faction.monsters, id: 'monsters');

    host.ready(north.toEngineDeck(), deckName: north.name);
    guest.ready(monsters.toEngineDeck());
    await settle();
    expect(guest.room.countdown, const Duration(seconds: 3));

    await scheduler.elapse(const Duration(seconds: 3));
    await settle();

    expect(host.room.started, isTrue);
    expect(guest.room.started, isTrue);
    final session = guest.openMatch();
    expect(session.table.localSeats, {Seat.two});
    await session.table.close();
  });

  test('комната истекла без гостя: хост узнаёт, что игры не будет', () async {
    final host = await hostOpened();

    clock.current = clock.current.add(const Duration(minutes: 31));
    await scheduler.elapse(const Duration(minutes: 31));
    await settle();

    expect(host.room.end, const RoomConnectionLost());
  });
}
