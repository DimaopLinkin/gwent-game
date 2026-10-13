import 'package:gwent/src/core/domain/app_info.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Версия приложения из пакета установки (для Android и iOS это `version` из `pubspec.yaml`).
final class PackageAppInfo implements AppInfo {
  /// Создаёт источник версии.
  const PackageAppInfo();

  @override
  Future<String> version() async => (await PackageInfo.fromPlatform()).version;
}
