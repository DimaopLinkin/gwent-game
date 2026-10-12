import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/data/game_ad_record.dart';
import 'package:gwent/src/features/lobby/data/lan_lobby.dart';
import 'package:gwent/src/features/lobby/data/service_directory.dart';
import 'package:gwent/src/features/lobby/domain/found_game.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/game_lobby.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';

import '../support/lobby_fakes.dart';

void main() {
  late FakeServiceDirectory directory;
  late LanLobby lobby;
  final hosted = <HostedGame>[];

  const ad = GameAd(id: 'game-1', hostName: 'Геральт', ruleset: testRuleset);

  setUp(() {
    directory = FakeServiceDirectory();
    lobby = LanLobby(directory: directory, localAddresses: () async => ['192.168.1.5']);
  });

  tearDown(() async {
    for (final game in hosted) {
      await game.close();
    }
    hosted.clear();
  });

  Future<HostedGame> host(GameAd ad) async {
    final game = await lobby.host(ad);
    hosted.add(game);
    return game;
  }

  test('гость находит партию и подключается к хосту', () async {
    final game = await host(ad);
    final record = directory.advertised[ad.id]!;
    expect(record.attributes, GameAdRecord.encode(ad));

    final found = await lobby.discover().firstWhere((games) => games.isNotEmpty);
    expect(found, [
      FoundGame(
        ad: ad,
        address: LanAddress(gameId: ad.id, hosts: const ['127.0.0.1'], port: record.port),
      ),
    ]);

    final connections = StreamIterator(game.connections);
    final guest = await lobby.join(found.single.address);
    expect(await connections.moveNext(), isTrue);
    final received = Completer<Uint8List>();
    connections.current.incoming.listen(received.complete);
    guest.send(Uint8List.fromList([42]));
    expect(await received.future, [42]);
    await guest.close();
    await connections.cancel();
  });

  test('приглашение ведёт на тот же сервер, что и поиск', () async {
    final game = await host(ad);
    final address = await game.address();
    expect(address, LanAddress(gameId: ad.id, hosts: const ['192.168.1.5'], port: directory.advertised[ad.id]!.port));
  });

  test('список следит за появлением, изменением и пропажей партий', () async {
    final lists = <List<FoundGame>>[];
    final subscription = lobby.discover().listen(lists.add);
    await _settle();
    expect(lists, [isEmpty], reason: 'первым идёт пустой список');

    final game = await host(ad);
    await _settle();
    expect(lists.last.single.ad, ad);

    await game.advertise(ad.copyWith(open: false));
    await _settle();
    expect(lists.last.single.ad.open, isFalse, reason: 'повторное объявление заменяет запись');

    final count = lists.length;
    directory.emit(ServiceFound(ServiceRecord(name: 'чужой', port: 1, attributes: const {'lib': 'bonsoir'})));
    directory.emit(
      ServiceFound(
        ServiceRecord(name: 'без адреса', port: 1, attributes: GameAdRecord.encode(ad), hosts: const ['fe80::1%en0']),
      ),
    );
    directory.emit(const ServiceLost('неизвестный'));
    await _settle();
    expect(lists, hasLength(count), reason: 'чужие и недоступные записи не меняют список');

    await game.close();
    await _settle();
    expect(lists.last, isEmpty);
    await subscription.cancel();
    expect(directory.activeBrowsers, 0, reason: 'отмена подписки останавливает поиск');
  });

  test('отказ службы поиска приходит ошибкой лобби', () async {
    final errors = <Object>[];
    final done = Completer<void>();
    lobby.discover().listen(null, onError: errors.add, onDone: done.complete);
    await _settle();
    directory.failBrowsing();
    await done.future;
    expect(errors, [isA<LobbyException>().having((e) => e.failure, 'failure', LobbyFailure.unavailable)]);
  });

  test('если объявить нельзя, сервер не остаётся слушать', () async {
    directory.failNextAdvertise = true;
    await expectLater(lobby.host(ad), throwsA(isA<LobbyException>()));
    expect(directory.advertised, isEmpty);
  });

  test('после закрытия партия не объявляется и не принимает соединения', () async {
    final game = await host(ad);
    final address = (await lobby.discover().firstWhere((games) => games.isNotEmpty)).single.address;
    final connectionsDone = Completer<void>();
    game.connections.listen(null, onDone: connectionsDone.complete);
    await game.close();
    await connectionsDone.future;
    expect(directory.advertised, isEmpty);
    await expectLater(
      lobby.join(address),
      throwsA(isA<LobbyException>().having((e) => e.failure, 'failure', LobbyFailure.unreachable)),
    );
    expect(() => game.advertise(ad), throwsStateError);
  });

  test('идентификатор объявленной партии не меняется', () async {
    final game = await host(ad);
    expect(() => game.advertise(const GameAd(id: 'game-2', hostName: 'x', ruleset: testRuleset)), throwsArgumentError);
    expect(game.ad, ad);
  });
}

/// Даёт асинхронным событиям каталога и сокетов дойти.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));
