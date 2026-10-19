import 'package:app_settings/app_settings.dart' as system;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:gwent/src/features/lobby/domain/network_access.dart';

/// Состояние сети и настройки телефона через `connectivity_plus` и `app_settings`.
final class DeviceNetworkAccess implements NetworkAccess {
  /// Создаёт доступ. [connectivity] и [platform] подставляются в тестах.
  DeviceNetworkAccess({Connectivity? connectivity, TargetPlatform? platform})
    : _connectivity = connectivity ?? Connectivity(),
      _platform = platform ?? defaultTargetPlatform;

  final Connectivity _connectivity;
  final TargetPlatform _platform;

  @override
  Future<bool> isOnWifi() async {
    final List<ConnectivityResult> results;
    try {
      results = await _connectivity.checkConnectivity();
    } on Object {
      // Не удалось узнать: не мешаем игре, ошибку сети покажет сама попытка.
      return true;
    }
    return results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet);
  }

  @override
  bool get asksLocalNetworkPermission => _platform == TargetPlatform.iOS;

  @override
  Future<void> openWifiSettings() => system.AppSettings.openAppSettings(type: system.AppSettingsType.wifi);

  @override
  Future<void> openAppSettings() => system.AppSettings.openAppSettings();
}
