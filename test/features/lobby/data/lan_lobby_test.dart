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

  test('закрытие во время повторного объявления не оставляет объявление в сети', () async {
    final game = await host(ad);
    directory.advertiseDelay = const Duration(milliseconds: 50);
    final readvertised = expectLater(game.advertise(ad.copyWith(open: false)), throwsStateError);
    // Закрываем, пока ОС ещё подтверждает новое объявление.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await game.close();
    await readvertised;
    expect(directory.advertised, isEmpty);
  });

  test('повторные объявления идут по очереди, последнее остаётся', () async {
    final game = await host(ad);
    directory.advertiseDelay = const Duration(milliseconds: 20);
    await Future.wait([game.advertise(ad.copyWith(open: false)), game.advertise(ad.copyWith(hostName: 'Цири'))]);
    expect(directory.advertised.keys, [ad.id]);
    expect(GameAdRecord.decode(directory.advertised[ad.id]!.attributes), ad.copyWith(hostName: 'Цири'));
    expect(game.ad, ad.copyWith(hostName: 'Цири'));
  });

  test('если ОС закрыла сервер, объявление снимается', () async {
    final game = await host(ad);
    final connectionsDone = Completer<void>();
    final subscription = game.connections.listen(null, onDone: connectionsDone.complete);
    await subscription.cancel();
    await _settle();
    expect(directory.advertised, isEmpty, reason: 'без слушателя соединений сервер и объявление закрываются');
  });

  test('одна партия под двумя именами сервиса видна один раз', () async {
    final lists = <List<FoundGame>>[];
    final subscription = lobby.discover().listen(lists.add);
    await host(ad);
    await _settle();
    final record = directory.advertised[ad.id]!;
    directory.emit(
      ServiceFound(
        ServiceRecord(
          name: '${ad.id} (2)',
          port: record.port + 1,
          attributes: record.attributes,
          hosts: const ['127.0.0.1'],
        ),
      ),
    );
    await _settle();
    expect(lists.last, hasLength(1));
    expect((lists.last.single.address as LanAddress).port, record.port + 1, reason: 'новее — последнее объявление');
    await subscription.cancel();
  });

  group('подделка объявления', () {
    // Самозванец копирует идентификатор настоящей партии (он открыт в объявлении) и объявляет её со своим адресом.
    ServiceFound forged({String name = 'самозванец', List<String> hosts = const ['10.0.0.66'], int port = 4444}) =>
        ServiceFound(ServiceRecord(name: name, port: port, attributes: GameAdRecord.encode(ad), hosts: hosts));

    test('объявление с тем же идентификатором с чужого адреса не подменяет настоящее', () async {
      final lists = <List<FoundGame>>[];
      final subscription = lobby.discover().listen(lists.add);
      await host(ad);
      await _settle();
      final real = lists.last.single;
      directory.emit(forged());
      await _settle();
      expect(lists.last, [real]);
      await subscription.cancel();
    });

    test('самозванец с адресом настоящего хоста в списке не получает свой адрес в приглашении', () async {
      final lists = <List<FoundGame>>[];
      final subscription = lobby.discover().listen(lists.add);
      await host(ad);
      await _settle();
      directory.emit(forged(hosts: const ['10.0.0.66', '127.0.0.1']));
      await _settle();
      final address = lists.last.single.address as LanAddress;
      expect(address.hosts, ['127.0.0.1'], reason: 'чужой адрес из объявления отбрасывается');
      await subscription.cancel();
    });

    test('когда настоящее объявление пропало, остаётся то, что было с ним по соседству', () async {
      final lists = <List<FoundGame>>[];
      final subscription = lobby.discover().listen(lists.add);
      // Хост сменил сеть: новое объявление пришло раньше, чем исчезло старое.
      directory.emit(forged(name: 'старое', hosts: const ['192.168.1.5'], port: 1111));
      directory.emit(forged(name: 'новое', hosts: const ['10.0.0.7'], port: 2222));
      await _settle();
      expect((lists.last.single.address as LanAddress).port, 1111);
      directory.emit(const ServiceLost('старое'));
      await _settle();
      expect((lists.last.single.address as LanAddress).port, 2222, reason: 'новое объявление не потеряно');
      await subscription.cancel();
    });
  });

  test('в приглашении сначала адреса Wi-Fi и частных сетей, сотовые и VPN в конце', () {
    expect(
      LanLobby.preferredAddresses([
        ('pdp_ip0', '10.12.0.5'),
        ('utun3', '100.64.1.2'),
        ('en0', '192.168.1.5'),
        ('rmnet_data0', '25.1.2.3'),
        ('wlan0', '172.20.10.2'),
      ]),
      ['192.168.1.5', '172.20.10.2', '10.12.0.5', '100.64.1.2', '25.1.2.3'],
    );
  });

  test('идентификатор объявленной партии не меняется', () async {
    final game = await host(ad);
    expect(() => game.advertise(const GameAd(id: 'game-2', hostName: 'x', ruleset: testRuleset)), throwsArgumentError);
    expect(game.ad, ad);
  });
}

/// Даёт асинхронным событиям каталога и сокетов дойти.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));
