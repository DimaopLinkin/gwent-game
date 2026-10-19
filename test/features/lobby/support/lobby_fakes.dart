import 'dart:async';

import 'package:gwent/src/features/lobby/data/service_directory.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent/src/features/lobby/domain/network_access.dart';
import 'package:gwent_net/gwent_net.dart';

/// Набор правил для тестов лобби.
const Ruleset testRuleset = Ruleset(id: 'gwent-w3-base', hash: 'abc123', engineVersion: 1);

/// Каталог DNS-SD в памяти: объявления видны поиску как записи с адресом [hosts].
final class FakeServiceDirectory implements ServiceDirectory {
  FakeServiceDirectory({this.hosts = const ['127.0.0.1']});

  /// Адреса, с которыми поиск возвращает объявленные здесь сервисы.
  final List<String> hosts;

  /// Действующие объявления по имени.
  final Map<String, ServiceRecord> advertised = {};

  /// Сколько раз объявляли сервис (включая повторные объявления).
  int advertiseCalls = 0;

  /// Следующее объявление откажет.
  bool failNextAdvertise = false;

  /// Сколько ОС подтверждает объявление.
  Duration advertiseDelay = Duration.zero;

  final List<StreamController<DirectoryEvent>> _browsers = [];

  /// Сколько поисков сейчас идёт.
  int get activeBrowsers => _browsers.where((browser) => !browser.isClosed).length;

  @override
  Future<ServiceAdvertisement> advertise(ServiceRecord record) async {
    advertiseCalls++;
    if (failNextAdvertise) {
      failNextAdvertise = false;
      throw const LobbyException(LobbyFailure.unavailable);
    }
    await Future<void>.delayed(advertiseDelay);
    advertised[record.name] = record;
    emit(
      ServiceFound(ServiceRecord(name: record.name, port: record.port, attributes: record.attributes, hosts: hosts)),
    );
    return _FakeAdvertisement(this, record.name);
  }

  @override
  Stream<DirectoryEvent> browse() {
    late final StreamController<DirectoryEvent> controller;
    controller = StreamController<DirectoryEvent>(
      onListen: () {
        for (final record in advertised.values) {
          controller.add(
            ServiceFound(
              ServiceRecord(name: record.name, port: record.port, attributes: record.attributes, hosts: hosts),
            ),
          );
        }
      },
      onCancel: () => _browsers.remove(controller),
    );
    _browsers.add(controller);
    return controller.stream;
  }

  /// Событие во все идущие поиски.
  void emit(DirectoryEvent event) {
    for (final browser in [..._browsers]) {
      if (browser.hasListener && !browser.isClosed) browser.add(event);
    }
  }

  /// Отказ службы поиска во всех идущих поисках.
  void failBrowsing() {
    for (final browser in [..._browsers]) {
      browser.addError(const LobbyException(LobbyFailure.unavailable));
      unawaited(browser.close());
    }
  }
}

final class _FakeAdvertisement implements ServiceAdvertisement {
  _FakeAdvertisement(this._directory, this._name);

  final FakeServiceDirectory _directory;
  final String _name;

  @override
  Future<void> stop() async {
    if (_directory.advertised.remove(_name) != null) _directory.emit(ServiceLost(_name));
  }
}

/// Сеть и настройки телефона в памяти: тест задаёт, включён ли Wi-Fi и спрашивает ли ОС доступ к локальной сети.
final class FakeNetworkAccess implements NetworkAccess {
  FakeNetworkAccess({this.wifiOn = true, this.asksLocalNetworkPermission = false});

  /// Телефон подключён к Wi-Fi.
  bool wifiOn;

  @override
  bool asksLocalNetworkPermission;

  /// Какие настройки открывали, по порядку: `wifi` или `app`.
  final List<String> openedSettings = [];

  @override
  Future<bool> isOnWifi() async => wifiOn;

  @override
  Future<void> openWifiSettings() async => openedSettings.add('wifi');

  @override
  Future<void> openAppSettings() async => openedSettings.add('app');
}
