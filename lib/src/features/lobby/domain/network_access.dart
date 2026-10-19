/// Что мешает сетевой игре на этом телефоне (макет 9, экраны 7c–7e).
enum NetworkProblem {
  /// Wi-Fi выключен или телефон не в Wi-Fi сети (7c).
  wifiOff,

  /// iOS скоро спросит доступ к локальной сети: игрок сначала читает, зачем (7d).
  localNetworkExplainer,

  /// iOS не дала доступ к локальной сети (7e).
  localNetworkDenied,
}

/// Состояние сети и системных разрешений телефона. Реализует слой data (ADR 0020).
abstract interface class NetworkAccess {
  /// Телефон подключён к Wi-Fi (или проводной сети).
  Future<bool> isOnWifi();

  /// ОС спрашивает разрешение на доступ к локальной сети (iOS) и после отказа его можно вернуть только в настройках.
  bool get asksLocalNetworkPermission;

  /// Открывает системные настройки Wi-Fi.
  Future<void> openWifiSettings();

  /// Открывает системные настройки этого приложения.
  Future<void> openAppSettings();
}
