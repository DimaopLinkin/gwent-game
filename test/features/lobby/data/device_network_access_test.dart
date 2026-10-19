import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/data/device_network_access.dart';

void main() {
  DeviceNetworkAccess accessWith(Object connectivity, {TargetPlatform platform = TargetPlatform.android}) =>
      DeviceNetworkAccess(connectivity: _FakeConnectivity(connectivity), platform: platform);

  test('Wi-Fi и проводная сеть годятся для игры', () async {
    expect(await accessWith([ConnectivityResult.wifi]).isOnWifi(), isTrue);
    expect(await accessWith([ConnectivityResult.ethernet]).isOnWifi(), isTrue);
    expect(await accessWith([ConnectivityResult.mobile, ConnectivityResult.wifi]).isOnWifi(), isTrue);
  });

  test('мобильная сеть и её отсутствие не годятся: телефоны не увидят друг друга', () async {
    expect(await accessWith([ConnectivityResult.mobile]).isOnWifi(), isFalse);
    expect(await accessWith([ConnectivityResult.none]).isOnWifi(), isFalse);
  });

  test('если состояние сети узнать не удалось, игре не мешают', () async {
    expect(await accessWith(Exception('нет данных')).isOnWifi(), isTrue);
  });

  test('доступ к локальной сети спрашивает только iOS', () {
    expect(accessWith(<ConnectivityResult>[], platform: TargetPlatform.iOS).asksLocalNetworkPermission, isTrue);
    expect(accessWith(<ConnectivityResult>[]).asksLocalNetworkPermission, isFalse);
  });
}

/// Состояние сети из теста: список результатов или ошибка, которую плагин бросает вместо ответа.
final class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this._answer);

  final Object _answer;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    final answer = _answer;
    if (answer is List<ConnectivityResult>) return answer;
    throw answer as Exception;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
}
