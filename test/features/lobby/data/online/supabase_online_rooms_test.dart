import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/data/online/online_config.dart';
import 'package:gwent/src/features/lobby/data/online/online_rooms.dart';
import 'package:gwent/src/features/lobby/data/online/supabase_online_rooms.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent/src/features/lobby/domain/online_session_store.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';

import '../../../../support/fakes.dart';
import '../../support/fake_supabase_server.dart';
import '../../support/lobby_fakes.dart';

final class _MemorySessions implements OnlineSessionStore {
  String? value;
  int clears = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String session) async => value = session;

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }
}

/// Клиент комнат против проекта Supabase в памяти: настоящие `SupabaseClient`, HTTP и WebSocket, свой сервер.
/// Тесты без `TestWidgetsFlutterBinding`: он закрывает настоящую сеть.
void main() {
  late FakeSupabaseServer server;
  late _MemorySessions sessions;
  late FakeClock clock;
  late SupabaseOnlineRooms rooms;

  const ad = GameAd(id: 'game-1', hostName: 'Цири', ruleset: testRuleset);

  Map<String, dynamic> roomReply({String id = 'room-1', String code = 'ABCDEF', bool open = true}) => {
    'ok': true,
    'room': {
      'id': id,
      'code': code,
      'host_name': 'Цири',
      'protocol': 1,
      'ruleset_id': 'gwent-w3-base',
      'ruleset_hash': 'abc123',
      'engine_version': 1,
      'open': open,
      'expires_at': '2026-10-20T12:30:00Z',
    },
  };

  SupabaseOnlineRooms roomsFor(
    FakeSupabaseServer server, {
    Duration requestTimeout = const Duration(seconds: 10),
  }) => SupabaseOnlineRooms(
    config: OnlineConfig(url: server.url, publishableKey: 'sb_publishable_test'),
    sessions: sessions,
    clock: clock,
    requestTimeout: requestTimeout,
  );

  setUp(() async {
    server = await FakeSupabaseServer.start();
    sessions = _MemorySessions();
    clock = FakeClock(DateTime.utc(2026, 10, 20, 12));
    rooms = roomsFor(server);
  });

  tearDown(() async {
    await rooms.dispose();
    await server.stop();
  });

  Matcher failure(LobbyFailure expected) =>
      throwsA(isA<LobbyException>().having((error) => error.failure, 'failure', expected));

  group('вход и создание комнаты', () {
    test('первое обращение входит анонимно, сохраняет сессию и зовёт create_room с токеном игрока', () async {
      server.functions['create_room'] = (_) => roomReply();

      final room = await rooms.create(ad);

      expect(server.signUps, 1);
      expect(sessions.value, isNotNull);
      expect((jsonDecode(sessions.value!) as Map<String, dynamic>)['access_token'], isA<String>());
      expect(room.id, 'room-1');
      expect(room.code.value, 'ABCDEF');
      expect(room.open, isTrue);
      expect(room.expiresAt, DateTime.utc(2026, 10, 20, 12, 30));
      final call = server.rpcCalls.single;
      expect(call.function, 'create_room');
      expect(call.params, {
        'p_host_name': 'Цири',
        'p_protocol': 1,
        'p_ruleset_id': 'gwent-w3-base',
        'p_ruleset_hash': 'abc123',
        'p_engine_version': 1,
      });
      expect(call.authorization, startsWith('Bearer ey'));
    });

    test('второй запрос живёт в той же сессии, без нового входа', () async {
      server.functions['create_room'] = (_) => roomReply();
      server.functions['join_room'] = (_) => roomReply(id: 'room-2');

      await rooms.create(ad);
      await rooms.join(RoomCode.tryParse('ABCDEF')!);

      expect(server.signUps, 1);
    });

    test('сохранённая годная сессия подхватывается без входа', () async {
      final stored = server.session('player-old');
      sessions.value = jsonEncode(stored);
      server.functions['create_room'] = (_) => roomReply();

      await rooms.create(ad);

      expect(server.signUps, 0);
      expect(server.rpcCalls.single.authorization, 'Bearer ${stored['access_token']}');
    });

    test('сохранённая просроченная сессия обновляется по refresh-токену', () async {
      sessions.value = jsonEncode(server.session('player-old', lifetime: const Duration(minutes: -5)));
      server.functions['create_room'] = (_) => roomReply();

      await rooms.create(ad);

      expect(server.refreshes, 1);
      expect(server.signUps, 0);
    });

    test('испорченная сохранённая сессия стирается, игрок входит заново', () async {
      sessions.value = 'не json';
      server.functions['create_room'] = (_) => roomReply();

      await rooms.create(ad);

      expect(sessions.clears, greaterThanOrEqualTo(1));
      expect(server.signUps, 1);
    });

    test('имя хоста очищается под правила базы: без невидимых знаков, в пределах 64 знаков, не пустое', () async {
      server.functions['create_room'] = (_) => roomReply();

      await rooms.create(const GameAd(id: 'game-1', hostName: 'Ци\u200dри\u200b', ruleset: testRuleset));
      await rooms.create(GameAd(id: 'game-1', hostName: 'я' * 100, ruleset: testRuleset));
      await rooms.create(const GameAd(id: 'game-1', hostName: '\u200d', ruleset: testRuleset));

      final names = server.rpcCalls.map((call) => call.params['p_host_name'] as String).toList();
      expect(names[0], 'Цири');
      expect(names[1].length, inInclusiveRange(1, 64));
      expect(names[2], '-');
    });
  });

  group('отказы сервера', () {
    final reasons = {
      'not_found': LobbyFailure.codeNotFound,
      'full': LobbyFailure.roomFull,
      'closed': LobbyFailure.roomClosed,
      'own_room': LobbyFailure.ownRoom,
      'too_many_attempts': LobbyFailure.tooManyAttempts,
      'неизвестная причина': LobbyFailure.unavailable,
    };
    for (final MapEntry(key: reason, value: expected) in reasons.entries) {
      test('join_room: $reason это $expected', () async {
        server.functions['join_room'] = (_) => {'ok': false, 'reason': reason};

        await expectLater(rooms.join(RoomCode.tryParse('ABCDEF')!), failure(expected));
      });
    }

    test('create_room: too_many_rooms это tooManyRooms', () async {
      server.functions['create_room'] = (_) => {'ok': false, 'reason': 'too_many_rooms'};

      await expectLater(rooms.create(ad), failure(LobbyFailure.tooManyRooms));
    });

    test('ответ не по контракту считается неисправностью сервиса, а не роняет приложение', () async {
      server.functions['create_room'] = (_) => [1, 2];
      await expectLater(rooms.create(ad), failure(LobbyFailure.unavailable));

      server.functions['create_room'] = (_) => {
        'ok': true,
        'room': {'id': 5},
      };
      await expectLater(rooms.create(ad), failure(LobbyFailure.unavailable));

      server.functions['create_room'] = (_) => roomReply(code: 'плохой');
      await expectLater(rooms.create(ad), failure(LobbyFailure.unavailable));
    });

    test('сервер ответил ошибкой: сервис недоступен', () async {
      server.rpcFailure = (500, {'message': 'сбой'});

      await expectLater(rooms.create(ad), failure(LobbyFailure.unavailable));
    });

    test('сервер не признал сессию: она забывается, следующая попытка входит заново', () async {
      server.rpcFailure = (401, {'code': 'PGRST301', 'message': 'JWT expired'});
      await expectLater(rooms.create(ad), failure(LobbyFailure.unavailable));

      server.rpcFailure = null;
      server.functions['create_room'] = (_) => roomReply();
      await rooms.create(ad);

      expect(server.signUps, 2);
    });

    test('спящий проект не отвечает: через срок сервис недоступен', () async {
      rooms = roomsFor(server, requestTimeout: const Duration(milliseconds: 100));
      server.rpcDelay = const Duration(milliseconds: 600);
      server.functions['create_room'] = (_) => roomReply();

      await expectLater(rooms.create(ad), failure(LobbyFailure.unavailable));
    });

    test('вход не удался: сервис недоступен, а следующая попытка пробует снова', () async {
      server.authFails = true;
      await expectLater(rooms.create(ad), failure(LobbyFailure.unavailable));

      server.authFails = false;
      server.functions['create_room'] = (_) => roomReply();
      await rooms.create(ad);

      expect(server.signUps, 1);
    });
  });

  group('управление комнатой и срок', () {
    test('setOpen и close зовут функции с идентификатором комнаты', () async {
      await rooms.setOpen('room-1', open: false);
      await rooms.close('room-1');

      expect(server.rpcCalls.map((call) => call.function), ['set_room_open', 'close_room']);
      expect(server.rpcCalls[0].params, {'p_room_id': 'room-1', 'p_open': false});
      expect(server.rpcCalls[1].params, {'p_room_id': 'room-1'});
    });

    test('standing: живая комната сообщает срок', () async {
      server.roomRow = {'closed_at': null, 'expires_at': '2026-10-20T12:30:00Z'};

      expect(
        await rooms.standing('room-1'),
        isA<RoomAlive>().having((alive) => alive.expiresAt, 'expiresAt', DateTime.utc(2026, 10, 20, 12, 30)),
      );
    });

    test('standing: нет строки, закрытая и просроченная комнаты — комнаты нет', () async {
      server.roomRow = null;
      expect(await rooms.standing('room-1'), isA<RoomGone>());

      server.roomRow = {'closed_at': '2026-10-20T12:10:00Z', 'expires_at': '2026-10-20T12:30:00Z'};
      expect(await rooms.standing('room-1'), isA<RoomGone>());

      server.roomRow = {'closed_at': null, 'expires_at': '2026-10-20T11:59:00Z'};
      expect(await rooms.standing('room-1'), isA<RoomGone>());
    });
  });
}
