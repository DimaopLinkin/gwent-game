import 'package:gwent/src/core/domain/app_info.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent_engine/gwent_engine.dart' show engineVersion;
import 'package:gwent_net/gwent_net.dart' show Ruleset;
import 'package:meta/meta.dart';

/// Что нужно сетевой игре от приложения: контент партии, набор правил для рукопожатия, версия и имя игрока.
@immutable
final class NetworkSetup {
  /// Создаёт набор.
  const NetworkSetup({required this.content, required this.ruleset, required this.appVersion, this.playerName});

  /// Контент партии.
  final GameContent content;

  /// Набор правил: пакет контента и версия движка. Игроки с разными наборами не могут играть вместе.
  final Ruleset ruleset;

  /// Версия приложения для рукопожатия.
  final String appVersion;

  /// Имя игрока из настроек; `null`, пока он его не задал.
  final String? playerName;
}

/// Итог подготовки сетевой игры.
sealed class NetworkSetupResult {
  const NetworkSetupResult();
}

/// Всё готово.
final class NetworkSetupReady extends NetworkSetupResult {
  /// Создаёт итог.
  const NetworkSetupReady(this.setup);

  /// Что нужно игре.
  final NetworkSetup setup;
}

/// Набор карт не прошёл проверку.
final class NetworkSetupUnavailable extends NetworkSetupResult {
  /// Создаёт итог.
  const NetworkSetupUnavailable();
}

/// Сценарий: собрать то, что нужно для создания сетевой игры и подключения к ней.
final class LoadNetworkSetup {
  /// Создаёт сценарий.
  const LoadNetworkSetup(this._content, this._appInfo, this._settings);

  final LoadGameContent _content;
  final AppInfo _appInfo;
  final WatchSettings _settings;

  /// Собирает набор. Сбой чтения версии приложения или настроек не мешает игре: версия заменяется прочерком,
  /// имя остаётся незаданным.
  Future<NetworkSetupResult> call() async {
    final GameContent content;
    switch (await _content()) {
      case GameContentReady(content: final ready):
        content = ready;
      case GameContentRejected():
        return const NetworkSetupUnavailable();
    }
    String version;
    try {
      version = await _appInfo.version();
    } on Object {
      version = '-';
    }
    String? name;
    try {
      name = (await _settings().first).playerName;
    } on Object {
      name = null;
    }
    final manifest = content.pack.manifest;
    return NetworkSetupReady(
      NetworkSetup(
        content: content,
        ruleset: Ruleset(id: manifest.packId, hash: manifest.contentHash, engineVersion: engineVersion),
        appVersion: version,
        playerName: name,
      ),
    );
  }
}
