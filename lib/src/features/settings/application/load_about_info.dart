import 'package:gwent/src/core/domain/app_info.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/settings/domain/about_info.dart';
import 'package:gwent_net/gwent_net.dart' show protocolVersion;

/// Сценарий: собрать версии приложения, сборки, набора карт и сетевого протокола.
///
/// Сбой чтения версии приложения или отказ набора карт не роняют сценарий: недостающее поле остаётся `null`, а экран
/// показывает прочерк.
final class LoadAboutInfo {
  /// Создаёт сценарий.
  const LoadAboutInfo(this._appInfo, this._loadGameContent);

  final AppInfo _appInfo;
  final LoadGameContent _loadGameContent;

  /// Собирает сведения.
  Future<AboutInfo> call() async {
    final appVersion = await _orNull(_appInfo.version);
    final buildNumber = await _orNull(_appInfo.buildNumber);
    final packVersion = switch (await _loadGameContent()) {
      GameContentReady(:final content) => content.pack.manifest.packVersion,
      GameContentRejected() => null,
    };
    return AboutInfo(
      appVersion: appVersion,
      buildNumber: buildNumber,
      protocolVersion: protocolVersion,
      packVersion: packVersion,
    );
  }

  /// Значение или `null`, если источник сломался: версии нужны только для подписей.
  Future<String?> _orNull(Future<String> Function() read) async {
    try {
      return await read();
    } on Object {
      return null;
    }
  }
}
