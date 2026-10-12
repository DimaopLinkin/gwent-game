import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/data/bonsoir_service_directory.dart';
import 'package:gwent/src/features/lobby/data/service_directory.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';

/// Перевод событий плагина `bonsoir` в события каталога. Плагин подменяется фейком платформы,
/// как это предусматривает `BonsoirPlatformInterface`.
void main() {
  late _FakeBonsoirPlatform platform;
  late BonsoirPlatformInterface original;
  const directory = BonsoirServiceDirectory(type: '_gwent._tcp', startTimeout: Duration(milliseconds: 200));

  setUp(() {
    original = BonsoirPlatformInterface.instance;
    platform = _FakeBonsoirPlatform();
    BonsoirPlatformInterface.instance = platform;
  });

  tearDown(() => BonsoirPlatformInterface.instance = original);

  final exampleRecord = ServiceRecord(name: 'game-1', port: 4000, attributes: const {'g': 'game-1', 'o': '1'});

  group('объявление', () {
    test('передаёт тип, имя, порт и TXT-запись и ждёт подтверждения ОС', () async {
      final pending = directory.advertise(exampleRecord);
      await pumpEventQueue();
      final broadcast = platform.broadcasts.single;
      expect(broadcast.service.name, 'game-1');
      expect(broadcast.service.type, '_gwent._tcp');
      expect(broadcast.service.port, 4000);
      expect(broadcast.service.attributes, exampleRecord.attributes);
      expect(broadcast.started, isTrue);
      broadcast.events.add(BonsoirBroadcastStartedEvent(service: broadcast.service));
      final advertisement = await pending;
      await advertisement.stop();
      expect(broadcast.stopped, isTrue);
    });

    test('отказ ОС — ошибка лобби, объявление снимается', () async {
      final pending = directory.advertise(exampleRecord);
      await pumpEventQueue();
      final broadcast = platform.broadcasts.single;
      broadcast.events.addError(PlatformException(code: 'broadcastError'));
      await expectLater(pending, throwsA(_unavailable));
      expect(broadcast.stopped, isTrue);
    });

    test('ошибка канала платформы — тоже ошибка лобби', () async {
      platform.failStart = true;
      await expectLater(directory.advertise(exampleRecord), throwsA(_unavailable));
    });

    test('без ответа ОС объявление считается начатым', () async {
      final advertisement = await directory.advertise(exampleRecord);
      expect(platform.broadcasts.single.stopped, isFalse);
      await advertisement.stop();
    });
  });

  group('поиск', () {
    test('найденный сервис разрешается и приходит с адресами, пропавший — по имени', () async {
      final events = <DirectoryEvent>[];
      final subscription = directory.browse().listen(events.add);
      await pumpEventQueue();
      final discovery = platform.discoveries.single;
      expect(discovery.type, '_gwent._tcp');
      expect(discovery.started, isTrue);

      final found = BonsoirService(name: 'game-1', type: '_gwent._tcp', port: 4000, attributes: const {'g': 'game-1'});
      discovery.events
        ..add(const BonsoirDiscoveryStartedEvent())
        ..add(BonsoirDiscoveryServiceFoundEvent(service: found));
      await pumpEventQueue();
      expect(discovery.resolved, [found]);
      expect(events, isEmpty, reason: 'без адресов сервис ещё не нужен');

      final resolved = found.copyWith(hostAddresses: ['192.168.1.5']);
      discovery.events
        ..add(BonsoirDiscoveryServiceResolvedEvent(service: resolved))
        ..add(
          BonsoirDiscoveryServiceUpdatedEvent(service: resolved.copyWith(attributes: const {'g': 'game-1', 'o': '0'})),
        )
        ..add(BonsoirDiscoveryServiceLostEvent(service: found));
      await pumpEventQueue();
      expect(events, [
        ServiceFound(
          ServiceRecord(name: 'game-1', port: 4000, attributes: const {'g': 'game-1'}, hosts: const ['192.168.1.5']),
        ),
        ServiceFound(
          ServiceRecord(
            name: 'game-1',
            port: 4000,
            attributes: const {'g': 'game-1', 'o': '0'},
            hosts: const ['192.168.1.5'],
          ),
        ),
        const ServiceLost('game-1'),
      ]);

      await subscription.cancel();
      expect(discovery.stopped, isTrue, reason: 'отмена подписки останавливает поиск');
    });

    test('отказ службы поиска — ошибка лобби, поиск останавливается', () async {
      final errors = <Object>[];
      final done = Completer<void>();
      directory.browse().listen(null, onError: errors.add, onDone: done.complete);
      await pumpEventQueue();
      final discovery = platform.discoveries.single;
      discovery.events.addError(PlatformException(code: 'discoveryError'));
      await done.future;
      expect(errors, [_unavailable]);
      await pumpEventQueue();
      expect(discovery.stopped, isTrue);
    });

    test('отмена во время запуска не оставляет поиск работать', () async {
      platform.initializeDelay = const Duration(milliseconds: 50);
      final subscription = directory.browse().listen(null);
      await subscription.cancel();
      expect(platform.discoveries.single.stopped, isTrue);
    });
  });
}

final Matcher _unavailable = isA<LobbyException>().having((e) => e.failure, 'failure', LobbyFailure.unavailable);

final class _FakeBonsoirPlatform extends BonsoirPlatformInterface {
  final List<_FakeBroadcast> broadcasts = [];
  final List<_FakeDiscovery> discoveries = [];
  bool failStart = false;
  Duration initializeDelay = Duration.zero;

  @override
  BonsoirAction<BonsoirBroadcastEvent> createBroadcastAction(BonsoirService service, {bool printLogs = kDebugMode}) {
    final action = _FakeBroadcast(this, service);
    broadcasts.add(action);
    return action;
  }

  @override
  BonsoirAction<BonsoirDiscoveryEvent> createDiscoveryAction(String type, {bool printLogs = kDebugMode}) {
    final action = _FakeDiscovery(this, type);
    discoveries.add(action);
    return action;
  }
}

abstract base class _FakeAction<T extends BonsoirEvent> extends BonsoirAction<T> {
  _FakeAction(this.platform);

  final _FakeBonsoirPlatform platform;
  final StreamController<T> events = StreamController<T>.broadcast();
  bool _initialized = false;
  bool started = false;
  bool stopped = false;

  @override
  Stream<T>? get eventStream => _initialized ? events.stream : null;

  @override
  Future<void> initialize() async {
    await Future<void>.delayed(platform.initializeDelay);
    _initialized = true;
  }

  @override
  bool get isReady => _initialized && !stopped;

  @override
  bool get isStopped => stopped;

  @override
  Future<void> start() async {
    if (platform.failStart) throw PlatformException(code: 'start');
    started = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    await events.close();
  }
}

final class _FakeBroadcast extends _FakeAction<BonsoirBroadcastEvent> {
  _FakeBroadcast(super.platform, this.service);

  final BonsoirService service;
}

final class _FakeDiscovery extends _FakeAction<BonsoirDiscoveryEvent> with ServiceResolver {
  _FakeDiscovery(super.platform, this.type);

  final String type;
  final List<BonsoirService> resolved = [];

  @override
  void resolveService(BonsoirService service) => resolved.add(service);

  @override
  bool supportsMdnsHostname() => false;
}
