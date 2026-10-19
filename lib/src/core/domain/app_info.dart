/// Сведения о самом приложении.
abstract interface class AppInfo {
  /// Версия приложения вида `1.0.0` (без номера сборки).
  Future<String> version();

  /// Номер сборки (число после `+` в версии `pubspec.yaml`).
  Future<String> buildNumber();
}
