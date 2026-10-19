import 'package:gwent/src/features/lobby/domain/network_access.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';

/// Сценарий: подготовить телефон к сетевой игре и объяснить игроку, почему она не началась (ADR 0020).
///
/// До первой попытки [check] ловит выключенный Wi-Fi и показывает пояснение перед системным запросом доступа к
/// локальной сети (iOS). После неудачи [diagnose] называет причину точнее общего «сеть недоступна».
final class NetworkReadiness {
  /// Создаёт сценарий. Пояснение запоминается в [settings].
  const NetworkReadiness(this._access, this._settings);

  final NetworkAccess _access;
  final SettingsRepository _settings;

  /// Что мешает начать игру прямо сейчас; `null`, если можно пробовать.
  ///
  /// Wi-Fi без интернета ОС может считать неосновной сетью, пока включены мобильные данные, поэтому до попытки
  /// игре мешает только полное отсутствие сети; выключенный Wi-Fi при мобильной сети выясняет [diagnose] после отказа.
  Future<NetworkProblem?> check() async {
    if (!await _access.hasNetwork()) return NetworkProblem.wifiOff;
    if (_access.asksLocalNetworkPermission && !(await _current()).localNetworkExplained) {
      return NetworkProblem.localNetworkExplainer;
    }
    return null;
  }

  /// Причина неудачи, когда служба сети отказала; `null`, если точнее общего отказа сказать нельзя.
  Future<NetworkProblem?> diagnose() async {
    if (!await _access.isOnWifi()) return NetworkProblem.wifiOff;
    return _access.asksLocalNetworkPermission ? NetworkProblem.localNetworkDenied : null;
  }

  /// Игрок прочитал пояснение: оно больше не показывается.
  Future<void> markExplained() async {
    final current = await _current();
    if (!current.localNetworkExplained) await _settings.save(current.copyWith(localNetworkExplained: true));
  }

  /// Открывает настройки, где игрок исправит [problem].
  Future<void> openSettings(NetworkProblem problem) => switch (problem) {
    NetworkProblem.wifiOff => _access.openWifiSettings(),
    NetworkProblem.localNetworkExplainer || NetworkProblem.localNetworkDenied => _access.openAppSettings(),
  };

  /// Открывает настройки приложения: например, где игрок разрешает камеру для сканера QR-кода.
  Future<void> openAppSettings() => _access.openAppSettings();

  Future<AppSettings> _current() => _settings.watch().first;
}
