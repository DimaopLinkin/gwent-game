import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_state.dart';
import 'package:gwent/src/features/lobby/presentation/create_online_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/join_online_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/join_online_game_state.dart';
import 'package:gwent/src/features/lobby/presentation/room_code_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/room_code_state.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';

import '../../../support/fakes.dart';
import '../support/online_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemorySettingsRepository settings;
  late OnlineHarness online;

  setUp(() {
    settings = InMemorySettingsRepository();
    online = OnlineHarness(settings);
  });

  tearDown(() => online.close());

  Future<T> eventually<T>(Future<T> Function() read, bool Function(T value) ready) async {
    var value = await read();
    for (var i = 0; i < 40 && !ready(value); i++) {
      await online.scheduler.elapse(const Duration(milliseconds: 100));
      value = await read();
    }
    return value;
  }

  group('создание комнаты', () {
    CreateOnlineGameCubit cubit({String fallback = 'Игрок'}) =>
        CreateOnlineGameCubit(online.hostGame, WatchSettings(settings), fallbackName: fallback);

    test('комната создаётся сразу; хост называется именем из настроек', () async {
      await settings.save(const AppSettings(playerName: ' Цири '));
      final create = cubit();
      addTearDown(create.close);

      await create.stream.firstWhere((state) => state is CreateGameCreated);

      expect(online.server.rooms.values.single.ad.hostName, 'Цири');
      expect(online.hostActive.current?.isOnline, isTrue);
    });

    test('без имени в настройках хост называется запасным именем', () async {
      final create = cubit(fallback: 'Вы');
      addTearDown(create.close);

      await create.stream.firstWhere((state) => state is CreateGameCreated);

      expect(online.server.rooms.values.single.ad.hostName, 'Вы');
    });

    test('сервис не отвечает: ошибка, а «Повторить» создаёт комнату, когда сервис проснулся', () async {
      online.server.offline = true;
      final create = cubit();
      addTearDown(create.close);

      final failed = await create.stream.firstWhere((state) => state is CreateGameFailed) as CreateGameFailed;
      expect(failed.result, isA<NetworkUnavailable>());
      expect(online.server.rooms, isEmpty);

      online.server.offline = false;
      unawaited(create.create());
      await create.stream.firstWhere((state) => state is CreateGameCreated);
      expect(online.server.rooms, hasLength(1));
    });

    test('слишком много комнат за час: причина приходит из сервиса', () async {
      online.hostRooms.createFailure = LobbyFailure.tooManyRooms;
      final create = cubit();
      addTearDown(create.close);

      final failed = await create.stream.firstWhere((state) => state is CreateGameFailed) as CreateGameFailed;

      expect(failed.result, isA<NetworkRoomRefused>().having((r) => r.failure, 'failure', LobbyFailure.tooManyRooms));
    });

    test('повторный вызов, пока комната создаётся, не создаёт вторую', () async {
      final gate = Completer<void>();
      online.hostRooms.createGate = gate;
      final create = cubit();
      addTearDown(create.close);
      await online.scheduler.flush();

      unawaited(create.create());
      gate.complete();
      await create.stream.firstWhere((state) => state is CreateGameCreated);

      expect(online.hostRooms.calls.where((call) => call == 'create'), hasLength(1));
    });

    test('экран закрыт, пока комната создавалась: комната закрывается на сервере', () async {
      final gate = Completer<void>();
      online.hostRooms.createGate = gate;
      final create = cubit();
      await online.scheduler.flush();
      await create.close();

      gate.complete();
      await online.scheduler.flush();
      await online.scheduler.flush();

      expect(online.hostActive.current, isNull);
      expect(online.server.alive(online.server.rooms.values.single.code.value), isNull);
    });
  });

  group('ввод кода', () {
    JoinOnlineGameCubit cubit() => JoinOnlineGameCubit(online.joinGame, WatchSettings(settings), fallbackName: 'Гость');

    Future<NetworkGame> openRoom() async {
      final result = await online.hostGame(gameName: 'Цири', playerName: 'Цири');
      return (result as NetworkGameOpened).game;
    }

    /// Гость вводит код [input]; время идёт, пока хост и сервис отвечают.
    Future<JoinOnlineGameState> enter(JoinOnlineGameCubit join, String input) async {
      await online.elapseUntil(join.join(input));
      return join.state;
    }

    test('верный код, в том числе строчными и с дефисом: гость входит под именем из настроек', () async {
      await settings.save(const AppSettings(playerName: 'Вереск'));
      final host = await openRoom();
      final code = (await online.codeOf(online.hostActive)).code;
      final join = cubit();
      addTearDown(join.close);

      final state = await enter(join, code.formatted.toLowerCase());
      await online.settle();

      expect(state, isA<JoinOnlineGameJoined>());
      expect(host.room.pendingGuest, 'Вереск');
    });

    test('без имени в настройках гость называется запасным именем', () async {
      final host = await openRoom();
      final join = cubit();
      addTearDown(join.close);

      await enter(join, (await online.codeOf(online.hostActive)).code.value);
      await online.settle();

      expect(host.room.pendingGuest, 'Гость');
    });

    test('не код: ответ без обращения к сервису, лимит попыток не тратится', () async {
      await openRoom();
      final join = cubit();
      addTearDown(join.close);

      for (final input in ['', 'ABC', 'ABCDEFG', 'AB0DEF', 'ABIDEF', 'ABODEF', 'AB1DEF', 'AB DE!']) {
        final state = await enter(join, input);
        expect(state, isA<JoinOnlineGameForm>().having((form) => form.badCode, 'badCode', isTrue), reason: input);
      }

      expect(online.guestRooms.calls, isEmpty);
    });

    test('комнаты с таким кодом нет: форма остаётся с причиной, правка текста её убирает', () async {
      await openRoom();
      final join = cubit();
      addTearDown(join.close);

      final state = await enter(join, 'ZZZZZZ') as JoinOnlineGameForm;

      expect(
        state.failure,
        isA<NetworkRoomRefused>().having((refused) => refused.failure, 'failure', LobbyFailure.codeNotFound),
      );
      join.edited();
      expect((join.state as JoinOnlineGameForm).failure, isNull);
    });

    test('восемь неверных кодов подряд: лимит попыток', () async {
      await openRoom();
      final join = cubit();
      addTearDown(join.close);

      for (var i = 0; i < 8; i++) {
        await enter(join, 'ZZZZZZ');
      }
      final state = await enter(join, 'ZZZZZZ') as JoinOnlineGameForm;

      expect(
        state.failure,
        isA<NetworkRoomRefused>().having((refused) => refused.failure, 'failure', LobbyFailure.tooManyAttempts),
      );
    });

    test('сервис не отвечает: недоступен; потом гость повторяет с тем же кодом и входит', () async {
      final host = await openRoom();
      final code = (await online.codeOf(online.hostActive)).code.value;
      final join = cubit();
      addTearDown(join.close);
      online.server.offline = true;

      final state = await enter(join, code) as JoinOnlineGameForm;
      expect(state.failure, isA<NetworkUnavailable>());

      online.server.offline = false;
      expect(await enter(join, code), isA<JoinOnlineGameJoined>());
      await online.settle();
      expect(host.room.pendingGuest, isNotNull);
    });

    test('код своей комнаты: причина «это ваша комната»', () async {
      await openRoom();
      final code = (await online.codeOf(online.hostActive)).code.value;
      final ownJoin = JoinOnlineGameCubit(
        online.phone('host'),
        WatchSettings(settings),
        fallbackName: 'Гость',
      );
      addTearDown(ownJoin.close);

      final state = await enter(ownJoin, code) as JoinOnlineGameForm;

      expect(
        state.failure,
        isA<NetworkRoomRefused>().having((refused) => refused.failure, 'failure', LobbyFailure.ownRoom),
      );
    });

    test('в комнате уже есть гость: «комната занята»', () async {
      final host = await openRoom();
      final code = (await online.codeOf(online.hostActive)).code.value;
      final first = cubit();
      addTearDown(first.close);
      await enter(first, code);
      await online.settle();
      host.admitGuest();
      await online.settle();
      final second = JoinOnlineGameCubit(online.phone('second'), WatchSettings(settings), fallbackName: 'Эмиель');
      addTearDown(second.close);

      final state = await enter(second, code) as JoinOnlineGameForm;

      expect(
        state.failure,
        isA<NetworkRoomRefused>().having((refused) => refused.failure, 'failure', LobbyFailure.roomFull),
      );
    });

    test('экран закрыт во время входа: гость не остаётся в игре', () async {
      await openRoom();
      final code = (await online.codeOf(online.hostActive)).code.value;
      final join = cubit();

      final joining = join.join(code);
      await join.close();
      await online.elapseUntil(joining);

      expect(online.guestActive.current, isNull);
    });
  });

  group('код комнаты хоста', () {
    test('показывает код и сменяет его, когда комната создаётся заново для нового гостя', () async {
      final result = await online.hostGame(gameName: 'Цири', playerName: 'Цири');
      final host = (result as NetworkGameOpened).game;
      final first = (await online.codeOf(online.hostActive)).code;
      final cubit = RoomCodeCubit(host, refresh: const Duration(milliseconds: 100));
      addTearDown(cubit.close);

      expect(cubit.state, isA<RoomCodeLoading>());
      await cubit.stream.firstWhere((state) => state is RoomCodeReady);
      expect((cubit.state as RoomCodeReady).code, first);

      // Гость вошёл и ушёл: сервер выдал хосту новую комнату с новым кодом.
      final joined = await online.elapseUntil(
        online.joinGame.byAddress(await online.codeOf(online.hostActive), playerName: 'Вереск'),
      );
      final guest = (joined as NetworkGameOpened).game;
      await online.settle();
      host.admitGuest();
      await online.settle();
      await guest.leave();
      await online.settle();

      final next = await eventually(
        () async => cubit.state,
        (state) => state is RoomCodeReady && state.code != first,
      );
      expect(next, isA<RoomCodeReady>());
      expect((next as RoomCodeReady).code, isNot(first));
      expect(next.code, (await online.codeOf(online.hostActive)).code);
    });

    test('игра закрыта: код больше не обновляется, держатель закрывается без ошибок', () async {
      final result = await online.hostGame(gameName: 'Цири', playerName: 'Цири');
      final host = (result as NetworkGameOpened).game;
      final cubit = RoomCodeCubit(host, refresh: const Duration(milliseconds: 20));
      await cubit.stream.firstWhere((state) => state is RoomCodeReady);

      await host.close();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await cubit.close();

      expect(cubit.isClosed, isTrue);
    });
  });
}
