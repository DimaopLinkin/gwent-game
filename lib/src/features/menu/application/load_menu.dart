import 'package:gwent/src/core/domain/app_info.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/application/ensure_starter_decks.dart';
import 'package:meta/meta.dart';

/// Что главное меню узнаёт при запуске.
@immutable
final class MenuInfo {
  /// Создаёт сведения.
  const MenuInfo({required this.appVersion, required this.packVersion});

  /// Версия приложения.
  final String appVersion;

  /// Версия набора карт; `null`, если набор не прошёл проверку.
  final int? packVersion;

  /// Набор карт загружен и проверен.
  bool get contentAvailable => packVersion != null;
}

/// Сценарий: подготовить приложение к первому показу меню.
///
/// Загружает набор карт, дарит каждой фракции стартовую колоду, если у неё колод нет, и называет версии приложения
/// и набора карт. Ошибки чтения набора пропускает как есть: меню покажет, что играть нельзя.
final class LoadMenu {
  /// Создаёт сценарий.
  const LoadMenu(this._appInfo, this._loadGameContent, this._ensureStarterDecks);

  final AppInfo _appInfo;
  final LoadGameContent _loadGameContent;
  final EnsureStarterDecks _ensureStarterDecks;

  /// Готовит меню.
  Future<MenuInfo> call() async {
    final appVersion = await _appInfo.version();
    switch (await _loadGameContent()) {
      case GameContentReady(:final content):
        await _ensureStarterDecks();
        return MenuInfo(appVersion: appVersion, packVersion: content.pack.manifest.packVersion);
      case GameContentRejected():
        return MenuInfo(appVersion: appVersion, packVersion: null);
    }
  }
}
