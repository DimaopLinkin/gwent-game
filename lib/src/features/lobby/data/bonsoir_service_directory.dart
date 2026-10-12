import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/services.dart';
import 'package:gwent/src/features/lobby/data/service_directory.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';

/// DNS-SD через плагин `bonsoir`: NSD на Android, Bonjour на iOS.
///
/// На iOS поиск требует `NSBonjourServices` и `NSLocalNetworkUsageDescription` в `Info.plist`. Если игрок
/// запретил доступ к локальной сети, iOS не сообщает об этом: поиск просто ничего не находит.
final class BonsoirServiceDirectory implements ServiceDirectory {
  /// Создаёт каталог для сервисов типа [type].
  const BonsoirServiceDirectory({required this.type, this.startTimeout = const Duration(seconds: 5)});

  /// Тип сервиса, например `_gwent._tcp`.
  final String type;

  /// Сколько ждать подтверждения объявления от ОС. Без ответа объявление считается начатым.
  final Duration startTimeout;

  @override
  Future<ServiceAdvertisement> advertise(ServiceRecord record) async {
    final broadcast = BonsoirBroadcast(
      service: BonsoirService(name: record.name, type: type, port: record.port, attributes: record.attributes),
    );
    try {
      await broadcast.initialize();
      final started = Completer<void>();
      final subscription = broadcast.eventStream?.listen(
        (event) {
          if (event is BonsoirBroadcastStartedEvent && !started.isCompleted) started.complete();
        },
        onError: (Object error) {
          if (!started.isCompleted) started.completeError(LobbyException(LobbyFailure.unavailable, error));
        },
      );
      await broadcast.start();
      try {
        await started.future.timeout(startTimeout, onTimeout: () {});
      } finally {
        await subscription?.cancel();
      }
    } on PlatformException catch (error) {
      await _stopQuietly(broadcast);
      throw LobbyException(LobbyFailure.unavailable, error);
    } on LobbyException {
      await _stopQuietly(broadcast);
      rethrow;
    }
    return _BonsoirAdvertisement(broadcast);
  }

  @override
  Stream<DirectoryEvent> browse() {
    late final StreamController<DirectoryEvent> controller;
    BonsoirDiscovery? discovery;
    StreamSubscription<BonsoirDiscoveryEvent>? subscription;
    Future<void>? starting;

    void fail(Object error) {
      if (controller.isClosed) return;
      controller.addError(LobbyException(LobbyFailure.unavailable, error));
      unawaited(controller.close());
    }

    Future<void> resolve(BonsoirDiscovery discovery, BonsoirService service) async {
      try {
        await service.resolve(discovery.serviceResolver);
      } on PlatformException {
        // Сервис, который не удалось разрешить, просто не появится в списке; поиск продолжается.
        return;
      }
    }

    void onEvent(BonsoirDiscovery discovery, BonsoirDiscoveryEvent event) {
      if (controller.isClosed) return;
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent(:final service):
          unawaited(resolve(discovery, service));
        case BonsoirDiscoveryServiceResolvedEvent(:final service) ||
            BonsoirDiscoveryServiceUpdatedEvent(:final service):
          if (service.hostAddresses.isEmpty) {
            unawaited(resolve(discovery, service));
          } else {
            controller.add(ServiceFound(_record(service)));
          }
        case BonsoirDiscoveryServiceLostEvent(:final service):
          controller.add(ServiceLost(service.name));
        case BonsoirDiscoveryStartedEvent() ||
            BonsoirDiscoveryStoppedEvent() ||
            BonsoirDiscoveryServiceResolveFailedEvent() ||
            BonsoirDiscoveryUnknownEvent():
          break;
      }
    }

    Future<void> start() async {
      final started = BonsoirDiscovery(type: type);
      discovery = started;
      try {
        await started.initialize();
        subscription = started.eventStream?.listen((event) => onEvent(started, event), onError: fail);
        await started.start();
      } on PlatformException catch (error) {
        fail(error);
      }
    }

    Future<void> stop() async {
      // Отмена во время запуска: сначала дождаться запуска, иначе поиск останется работать.
      await starting;
      await subscription?.cancel();
      final current = discovery;
      if (current != null) await _stopQuietly(current);
    }

    controller = StreamController<DirectoryEvent>(onListen: () => starting = start(), onCancel: stop);
    return controller.stream;
  }

  static ServiceRecord _record(BonsoirService service) => ServiceRecord(
    name: service.name,
    port: service.port,
    attributes: service.attributes,
    hosts: service.hostAddresses,
  );

  static Future<void> _stopQuietly(BonsoirActionHandler<BonsoirEvent> action) async {
    if (!action.isReady) return;
    try {
      await action.stop();
    } on PlatformException {
      // Служба ОС уже остановила действие: снимать нечего.
      return;
    }
  }
}

final class _BonsoirAdvertisement implements ServiceAdvertisement {
  _BonsoirAdvertisement(this._broadcast);

  final BonsoirBroadcast _broadcast;

  @override
  Future<void> stop() => BonsoirServiceDirectory._stopQuietly(_broadcast);
}
