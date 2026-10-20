import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/data/online/online_lobby.dart';
import 'package:gwent/src/features/lobby/data/online/room_message.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/game_lobby.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';

import '../../../../support/fakes.dart';
import '../../support/fake_online_server.dart';
import '../../support/lobby_fakes.dart';

void main() {
  late FakeClock clock;
  late FakeScheduler scheduler;
  late FakeOnlineServer server;
  late FakeOnlineRooms hostRooms;
  late FakeOnlineRooms guestRooms;
  late OnlineLobby hostLobby;
  late OnlineLobby guestLobby;

  const ad = GameAd(id: 'game-1', hostName: 'Цири', ruleset: testRuleset);

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 10, 20, 12));
    scheduler = FakeScheduler();
    server = FakeOnlineServer(clock);
    hostRooms = server.phone('host');
    guestRooms = server.phone('guest');
    hostLobby = OnlineLobby(rooms: hostRooms, scheduler: scheduler, clock: clock);
    guestLobby = OnlineLobby(rooms: guestRooms, scheduler: scheduler, clock: clock);
  });

  Future<void> settle() async {
    for (var i = 0; i < 3; i++) {
      await scheduler.flush();
    }
  }

  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

  /// Принимает соединения хоста в список, как это делает `NetworkGame`.
  List<Transport> collect(HostedGame hosted) {
    final accepted = <Transport>[];
    hosted.connections.listen(accepted.add);
    return accepted;
  }

  Future<OnlineAddress> addressOf(HostedGame hosted) async => (await hosted.address()) as OnlineAddress;

  group('хост', () {
    test('создаёт комнату и показывает её код', () async {
      final hosted = await hostLobby.host(ad);

      final address = await addressOf(hosted);
      final room = server.rooms.values.single;
      expect(address.code, room.code);
      expect(room.ad, ad);
      expect(hosted.ad, ad);
      expect(room.channels, hasLength(1));
    });

    test('сервис недоступен: партию создать нельзя', () async {
      server.offline = true;

      await expectLater(
        hostLobby.host(ad),
        throwsA(isA<LobbyException>().having((error) => error.failure, 'failure', LobbyFailure.unavailable)),
      );
    });

    test('не удалось войти в канал: созданная комната закрывается', () async {
      hostRooms.failConnect = true;

      await expectLater(hostLobby.host(ad), throwsA(isA<LobbyException>()));
      await settle();

      expect(server.rooms.values.single.closedAt, isNotNull);
    });

    test('партия, объявленная закрытой, закрывает приём гостей на сервере', () async {
      await hostLobby.host(ad.copyWith(open: false));

      expect(server.rooms.values.single.open, isFalse);
    });

    test('поиска нет: список пуст, а поток не закрывается', () async {
      final lists = <int>[];
      var done = false;
      final subscription = hostLobby.discover().listen((games) => lists.add(games.length), onDone: () => done = true);
      await settle();

      expect(lists, [0]);
      expect(done, isFalse);
      await subscription.cancel();
    });
  });

  group('соединения', () {
    test('кадры идут от гостя к хосту и обратно', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final guest = await guestLobby.join(await hosted.address());
      final fromGuest = <String>[];
      guest.incoming.listen((frame) => fromGuest.add(utf8.decode(frame)));

      guest.send(bytes('{"hello":1}'));
      await settle();
      expect(accepted, hasLength(1));
      final fromHost = <String>[];
      accepted.single.incoming.listen((frame) => fromHost.add(utf8.decode(frame)));
      await settle();
      expect(fromHost, ['{"hello":1}'], reason: 'кадр, пришедший до подписки хоста партии, не теряется');

      accepted.single.send(bytes('{"welcome":2}'));
      await settle();
      expect(fromGuest, ['{"welcome":2}']);
    });

    test('кадры с кириллицей и эмодзи доходят без искажений', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final guest = await guestLobby.join(await hosted.address());

      guest.send(bytes('{"name":"Цири 🐺"}'));
      await settle();
      final received = <String>[];
      accepted.single.incoming.listen((frame) => received.add(utf8.decode(frame)));
      await settle();

      expect(received, ['{"name":"Цири 🐺"}']);
    });

    test('кадр не в UTF-8 в канал не уходит', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final guest = await guestLobby.join(await hosted.address());

      guest.send(Uint8List.fromList([0xff, 0xfe]));
      await settle();

      expect(accepted, isEmpty);
    });

    test('хост видит нового гостя по первому кадру, а не по входу в канал', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      await guestLobby.join(await hosted.address());
      await settle();

      expect(accepted, isEmpty);
    });

    test('новое подключение гостя получает свой транспорт, а старое закрывается сообщением bye', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final address = await hosted.address();
      final first = await guestLobby.join(address);
      first.send(bytes('1'));
      await settle();
      var firstClosed = false;
      accepted.single.incoming.listen((_) {}, onDone: () => firstClosed = true);

      await first.close();
      final second = await guestLobby.join(address);
      second.send(bytes('2'));
      await settle();

      expect(firstClosed, isTrue);
      expect(accepted, hasLength(2));
      final received = <String>[];
      accepted.last.incoming.listen((frame) => received.add(utf8.decode(frame)));
      await settle();
      expect(received, ['2']);
      expect(
        guestRooms.calls.where((call) => call.startsWith('join:')),
        hasLength(1),
        reason: 'место гостя занято один раз',
      );
    });

    test('ответ хоста доходит только тому подключению гостя, которому адресован', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final address = await hosted.address();
      final first = await guestLobby.join(address);
      final second = await guestLobby.join(address);
      final firstFrames = <String>[];
      final secondFrames = <String>[];
      first.incoming.listen((frame) => firstFrames.add(utf8.decode(frame)));
      second.incoming.listen((frame) => secondFrames.add(utf8.decode(frame)));
      first.send(bytes('a'));
      second.send(bytes('b'));
      await settle();

      accepted.last.send(bytes('reply-b'));
      await settle();

      expect(firstFrames, isEmpty);
      expect(secondFrames, ['reply-b']);
    });

    test('хост закрывает соединение: гость видит конец потока', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final guest = await guestLobby.join(await hosted.address());
      var guestClosed = false;
      guest.incoming.listen((_) {}, onDone: () => guestClosed = true);
      guest.send(bytes('hello'));
      await settle();

      await accepted.single.close();
      await settle();

      expect(guestClosed, isTrue);
    });

    test('хост держит не больше трёх соединений: самое старое закрывается', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final address = await hosted.address();
      final guests = [for (var i = 0; i < 4; i++) await guestLobby.join(address)];
      // Как в партии: гость уже занял место, поэтому объявление закрыто и комната не пересоздаётся.
      await hosted.advertise(ad.copyWith(open: false));
      final closed = List.filled(4, false);

      for (final (index, guest) in guests.indexed) {
        guest.send(bytes('$index'));
        await settle();
        accepted[index].incoming.listen((_) {}, onDone: () => closed[index] = true);
      }
      await settle();

      expect(accepted, hasLength(4));
      expect(closed, [true, false, false, false]);
    });

    test('сообщения от стороны хоста в канале хост игнорирует: соединений они не создают', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final guest = await guestLobby.join(await hosted.address());
      final heard = <String>[];
      guest.incoming.listen((frame) => heard.add(utf8.decode(frame)));
      final room = server.rooms.values.single;
      // Второй вход игрока в канал: нечестный гость пишет в канал от имени хоста.
      final raw = await guestRooms.connect(room.id);

      raw.send(const FrameMessage(cid: 7, from: RoomSide.host, data: 'x'));
      raw.send(const ByeMessage(cid: 7, from: RoomSide.host));
      await settle();

      expect(accepted, isEmpty);
      expect(heard, isEmpty);
    });
  });

  group('смена гостя', () {
    test('хост, у которого был гость, при открытии партии создаёт комнату заново с новым кодом', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final oldAddress = await addressOf(hosted);
      final oldRoom = server.rooms.values.single;
      final guest = await guestLobby.join(oldAddress);
      guest.send(bytes('hello'));
      await settle();
      var oldClosed = false;
      accepted.single.incoming.listen((_) {}, onDone: () => oldClosed = true);

      await hosted.advertise(ad.copyWith(open: false));
      await hosted.advertise(ad.copyWith(open: true));

      final newAddress = await addressOf(hosted);
      expect(newAddress.code, isNot(oldAddress.code));
      expect(oldRoom.closedAt, isNotNull);
      expect(oldClosed, isTrue, reason: 'соединения прежней комнаты закрыты');
      expect(server.rooms.values.where(server.isAlive), hasLength(1));
      expect(oldRoom.channels, hasLength(1), reason: 'в старом канале остался только прежний гость');

      final other = server.phone('other');
      await expectLater(
        OnlineLobby(rooms: other, scheduler: scheduler, clock: clock).join(oldAddress),
        throwsA(isA<LobbyException>().having((error) => error.failure, 'failure', LobbyFailure.codeNotFound)),
      );
      final newGuest = await OnlineLobby(rooms: other, scheduler: scheduler, clock: clock).join(newAddress);
      newGuest.send(bytes('hi'));
      await settle();
      expect(accepted, hasLength(2));
    });

    test('прежний гость остаётся в старой комнате и ничего не узнаёт про нового', () async {
      final hosted = await hostLobby.host(ad);
      collect(hosted);
      final oldAddress = await addressOf(hosted);
      final oldGuest = await guestLobby.join(oldAddress);
      final heard = <String>[];
      oldGuest.incoming.listen((frame) => heard.add(utf8.decode(frame)));
      oldGuest.send(bytes('hello'));
      await settle();

      await hosted.advertise(ad.copyWith(open: true));
      final other = OnlineLobby(rooms: server.phone('other'), scheduler: scheduler, clock: clock);
      final newGuest = await other.join(await hosted.address());
      newGuest.send(bytes('hi'));
      await settle();

      expect(heard, isEmpty);
    });

    test('без гостя партия остаётся в той же комнате: открытие только меняет приём гостей', () async {
      final hosted = await hostLobby.host(ad);
      final room = server.rooms.values.single;

      await hosted.advertise(ad.copyWith(open: false));
      expect(room.open, isFalse);
      await hosted.advertise(ad.copyWith(open: true));

      expect(room.open, isTrue);
      expect(server.rooms, hasLength(1));
    });

    test('повторное объявление с тем же состоянием на сервер не ходит', () async {
      final hosted = await hostLobby.host(ad);
      hostRooms.calls.clear();

      await hosted.advertise(ad);

      expect(hostRooms.calls, isEmpty);
    });

    test('новую комнату создать не удалось: хост остаётся в прежней, следующая попытка повторит', () async {
      final hosted = await hostLobby.host(ad);
      collect(hosted);
      final address = await addressOf(hosted);
      final guest = await guestLobby.join(address);
      guest.send(bytes('hello'));
      await settle();

      server.offline = true;
      await expectLater(hosted.advertise(ad.copyWith(open: true)), throwsA(isA<LobbyException>()));
      server.offline = false;
      expect(await addressOf(hosted), address);

      await hosted.advertise(ad.copyWith(open: true));
      expect(await addressOf(hosted), isNot(address));
    });

    test('хост отказал гостю на рукопожатии и закрыл соединение: комната пересоздаётся без объявления', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final oldAddress = await addressOf(hosted);
      final guest = await guestLobby.join(oldAddress);
      guest.send(bytes('hello'));
      await settle();

      await accepted.single.close();
      await settle();

      final newAddress = await addressOf(hosted);
      expect(newAddress, isNot(oldAddress));
      final other = OnlineLobby(rooms: server.phone('other'), scheduler: scheduler, clock: clock);
      expect(await other.join(newAddress), isA<Transport>());
    });

    test('пересоздание не удалось по сети: таймер повторяет попытку', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final oldAddress = await addressOf(hosted);
      final guest = await guestLobby.join(oldAddress);
      guest.send(bytes('hello'));
      await settle();

      server.offline = true;
      await accepted.single.close();
      await settle();
      server.offline = false;
      await scheduler.elapse(hostLobby.standingRetry);
      await settle();

      expect(await addressOf(hosted), isNot(oldAddress));
    });

    test(
      'новая комната создана, но в её канал не войти: партия заканчивается, а не остаётся в мёртвой комнате',
      () async {
        final hosted = await hostLobby.host(ad);
        final accepted = <Transport>[];
        var done = false;
        hosted.connections.listen(accepted.add, onDone: () => done = true);
        final guest = await guestLobby.join(await addressOf(hosted));
        guest.send(bytes('hello'));
        await settle();

        hostRooms.failConnects = 3;
        await accepted.single.close();
        await scheduler.elapse(const Duration(seconds: 5));
        await settle();

        expect(done, isTrue);
        expect(server.rooms.values.where(server.isAlive), isEmpty);
      },
    );

    test('партию закрыли, пока создавалась новая комната: новая комната не остаётся открытой', () async {
      final hosted = await hostLobby.host(ad);
      collect(hosted);
      final guest = await guestLobby.join(await addressOf(hosted));
      guest.send(bytes('hello'));
      await settle();

      final gate = hostRooms.createGate = Completer<void>();
      final renewing = hosted.advertise(ad.copyWith(open: true));
      await settle();
      await hosted.close();
      gate.complete();
      await renewing;
      await settle();
      await scheduler.elapse(const Duration(seconds: 30));

      expect(server.rooms.values.where(server.isAlive), isEmpty);
      expect(server.rooms['room-2']!.channels, isEmpty);
    });

    test('запоздавший кадр закрытого соединения нового соединения не создаёт', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final guest = await guestLobby.join(await addressOf(hosted));
      await hosted.advertise(ad.copyWith(open: false));
      guest.send(bytes('hello'));
      await settle();
      await accepted.single.close();
      await settle();

      guest.send(bytes('поздно'));
      await settle();

      expect(accepted, hasLength(1));
    });

    test('идентификатор партии менять нельзя, закрытая партия не объявляется', () async {
      final hosted = await hostLobby.host(ad);

      expect(
        () => hosted.advertise(const GameAd(id: 'other', hostName: 'Цири', ruleset: testRuleset)),
        throwsArgumentError,
      );
      await hosted.close();
      await expectLater(hosted.advertise(ad), throwsStateError);
    });
  });

  group('закрытие и срок жизни', () {
    test('закрытие партии закрывает комнату и поток соединений', () async {
      final hosted = await hostLobby.host(ad);
      var done = false;
      hosted.connections.listen((_) {}, onDone: () => done = true);
      final room = server.rooms.values.single;

      await hosted.close();
      await settle();

      expect(done, isTrue);
      expect(room.closedAt, isNotNull);
      expect(room.channels, isEmpty);
    });

    test('отмена подписки на соединения закрывает партию', () async {
      final hosted = await hostLobby.host(ad);
      final subscription = hosted.connections.listen((_) {});
      final room = server.rooms.values.single;

      await subscription.cancel();
      await settle();

      expect(room.closedAt, isNotNull);
      expect(room.channels, isEmpty);
    });

    test('принятые соединения остаются открытыми, пока хост партии их не закроет: ими владеет он', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final guest = await guestLobby.join(await hosted.address());
      final heard = <String>[];
      guest.incoming.listen((frame) => heard.add(utf8.decode(frame)));
      guest.send(bytes('hello'));
      await settle();
      final room = server.rooms.values.single;

      await hosted.close();
      accepted.single.send(bytes('lobby-closed'));
      await settle();
      expect(room.channels, hasLength(2), reason: 'канал нужен принятому соединению');
      expect(heard, ['lobby-closed']);

      await accepted.single.close();
      await settle();
      expect(room.channels, isEmpty, reason: 'канал хоста закрыт вместе с последним соединением, а гость ушёл по bye');
    });

    test('если хост партии соединения не закрыл, канал закрывается по таймеру', () async {
      final hosted = await hostLobby.host(ad);
      final accepted = collect(hosted);
      final guest = await guestLobby.join(await hosted.address());
      guest.send(bytes('hello'));
      await settle();
      final room = server.rooms.values.single;

      await hosted.close();
      await scheduler.elapse(hostLobby.closeLinger);
      await settle();

      expect(room.channels, hasLength(1));
      var closed = false;
      accepted.single.incoming.listen((_) {}, onDone: () => closed = true);
      await settle();
      expect(closed, isTrue);
    });

    test('комната без гостя закрылась по сроку: поток соединений закрывается, код не работает', () async {
      final hosted = await hostLobby.host(ad);
      var done = false;
      hosted.connections.listen((_) {}, onDone: () => done = true);

      clock.current = clock.current.add(const Duration(minutes: 31));
      await scheduler.elapse(const Duration(minutes: 31));
      await settle();

      expect(done, isTrue);
      await expectLater(hosted.address(), throwsA(isA<LobbyException>()));
    });

    test('вход гостя продлевает комнату: в срок хост узнаёт новый срок и ждёт дальше', () async {
      final hosted = await hostLobby.host(ad);
      var done = false;
      hosted.connections.listen((_) {}, onDone: () => done = true);
      final guest = await guestLobby.join(await hosted.address());
      guest.send(bytes('hello'));
      await settle();

      clock.current = clock.current.add(const Duration(minutes: 31));
      await scheduler.elapse(const Duration(minutes: 31));
      await settle();

      expect(done, isFalse);
      expect(hostRooms.calls.where((call) => call.startsWith('standing:')), isNotEmpty);

      clock.current = clock.current.add(const Duration(hours: 6));
      await scheduler.elapse(const Duration(hours: 6));
      await settle();
      expect(done, isTrue, reason: 'через шесть часов комната закрыта и у гостя');
    });

    test('сервис не ответил в срок: проверка повторяется, партия не заканчивается', () async {
      final hosted = await hostLobby.host(ad);
      var done = false;
      hosted.connections.listen((_) {}, onDone: () => done = true);
      server.offline = true;

      await scheduler.elapse(const Duration(minutes: 31));
      await settle();
      expect(done, isFalse);

      server.offline = false;
      await scheduler.elapse(hostLobby.standingRetry);
      await settle();
      expect(done, isFalse, reason: 'по серверному времени комната ещё жива');
    });

    test('неполадка канала: хост проверяет комнату, и если её нет, партия заканчивается', () async {
      final hosted = await hostLobby.host(ad);
      var done = false;
      hosted.connections.listen((_) {}, onDone: () => done = true);
      final room = server.rooms.values.single;
      final channel = room.channels.single;

      channel.fail();
      await settle();
      expect(done, isFalse, reason: 'комната жива, канал вернётся сам');

      room.closedAt = clock.now();
      clock.current = clock.current.add(hostLobby.standingRetry);
      channel.fail();
      await settle();
      expect(done, isTrue);
    });
  });

  group('гость', () {
    OnlineAddress codeOf(HostedGame hosted) => OnlineAddress(server.rooms.values.last.code);

    test('неверный код: ошибка называет причину', () async {
      await expectLater(
        guestLobby.join(OnlineAddress(RoomCode.tryParse('ABCDEF')!)),
        throwsA(isA<LobbyException>().having((error) => error.failure, 'failure', LobbyFailure.codeNotFound)),
      );
    });

    test('свой код, занятая и закрытая комнаты называются своими причинами', () async {
      final hosted = await hostLobby.host(ad);
      final address = codeOf(hosted);
      Future<LobbyFailure> failure(OnlineLobby lobby) async {
        try {
          await lobby.join(address);
        } on LobbyException catch (error) {
          return error.failure;
        }
        throw StateError('вход удался');
      }

      expect(await failure(hostLobby), LobbyFailure.ownRoom);
      await guestLobby.join(address);
      final other = OnlineLobby(rooms: server.phone('other'), scheduler: scheduler, clock: clock);
      expect(await failure(other), LobbyFailure.roomFull);

      final closedHost = await OnlineLobby(rooms: server.phone('h2'), scheduler: scheduler, clock: clock).host(
        const GameAd(id: 'g2', hostName: 'Эмиель', ruleset: testRuleset, open: false),
      );
      final closedAddress = codeOf(closedHost);
      await expectLater(
        OnlineLobby(rooms: server.phone('g3'), scheduler: scheduler, clock: clock).join(closedAddress),
        throwsA(isA<LobbyException>().having((error) => error.failure, 'failure', LobbyFailure.roomClosed)),
      );
    });

    test('адрес из локальной сети онлайн-лобби не подходит', () async {
      await expectLater(
        guestLobby.join(LanAddress(gameId: 'g', hosts: const ['10.0.0.1'], port: 1)),
        throwsA(isA<LobbyException>().having((error) => error.failure, 'failure', LobbyFailure.unreachable)),
      );
      expect(guestRooms.calls, isEmpty);
    });

    test('сервис недоступен: гость узнаёт об этом, а не о неверном коде', () async {
      server.offline = true;

      await expectLater(
        guestLobby.join(OnlineAddress(RoomCode.tryParse('ABCDEF')!)),
        throwsA(isA<LobbyException>().having((error) => error.failure, 'failure', LobbyFailure.unavailable)),
      );
    });

    test('возвращение к хосту не ходит за комнатой на сервер: неверные коды не копятся', () async {
      final hosted = await hostLobby.host(ad);
      collect(hosted);
      final address = codeOf(hosted);
      for (var i = 0; i < 12; i++) {
        final transport = await guestLobby.join(address);
        await transport.close();
      }

      expect(guestRooms.calls.where((call) => call.startsWith('join:')), hasLength(1));
      expect(
        guestRooms.calls.where((call) => call.startsWith('connect:')),
        hasLength(12),
        reason: 'канал свежий на каждую попытку',
      );
    });

    test('комнату закрыли: возвращаться некуда, и сервер об этом не спрашивается, пока гость помнит', () async {
      final hosted = await hostLobby.host(ad);
      collect(hosted);
      final address = codeOf(hosted);
      final first = await guestLobby.join(address);
      await first.close();
      await hosted.close();
      guestRooms.calls.clear();

      for (var i = 0; i < 3; i++) {
        await expectLater(
          guestLobby.join(address),
          throwsA(isA<LobbyException>().having((error) => error.failure, 'failure', LobbyFailure.unreachable)),
        );
      }
      expect(guestRooms.calls.where((call) => call.startsWith('join:')), isEmpty);
      expect(guestRooms.calls.where((call) => call.startsWith('standing:')), hasLength(1));

      clock.current = clock.current.add(guestLobby.deadRoomMemory);
      await expectLater(
        guestLobby.join(address),
        throwsA(isA<LobbyException>().having((error) => error.failure, 'failure', LobbyFailure.codeNotFound)),
      );
    });

    test('нет связи с сервисом при возвращении: это недоступность, а не конец комнаты', () async {
      final hosted = await hostLobby.host(ad);
      collect(hosted);
      final address = codeOf(hosted);
      await (await guestLobby.join(address)).close();

      server.offline = true;
      await expectLater(
        guestLobby.join(address),
        throwsA(isA<LobbyException>().having((error) => error.failure, 'failure', LobbyFailure.unavailable)),
      );
      server.offline = false;

      final again = await guestLobby.join(address);
      expect(again.incoming, isNotNull);
    });

    test('канал гостя закрывается вместе с последним соединением', () async {
      final hosted = await hostLobby.host(ad);
      collect(hosted);
      final address = codeOf(hosted);
      final room = server.rooms.values.single;
      final first = await guestLobby.join(address);
      final second = await guestLobby.join(address);
      expect(room.channels, hasLength(2));

      await first.close();
      await settle();
      expect(room.channels, hasLength(2), reason: 'второе соединение держит канал');

      await second.close();
      await settle();
      expect(room.channels, hasLength(1));
    });
  });
}
