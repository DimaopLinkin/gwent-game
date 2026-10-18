import 'package:meta/meta.dart';

/// Сведения о приложении для группы «О приложении» и «Данные карт».
@immutable
final class AboutInfo {
  /// Создаёт сведения.
  const AboutInfo({required this.protocolVersion, this.appVersion, this.buildNumber, this.packVersion});

  /// Версия приложения вида `1.0.0`; `null`, если узнать её не удалось.
  final String? appVersion;

  /// Номер сборки; `null`, если узнать его не удалось.
  final String? buildNumber;

  /// Версия сетевого протокола.
  final int protocolVersion;

  /// Версия набора карт; `null`, если набор не прошёл проверку.
  final int? packVersion;
}
