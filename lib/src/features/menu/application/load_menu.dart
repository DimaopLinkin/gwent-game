import 'package:gwent/src/core/domain/app_info.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/application/ensure_starter_decks.dart';
import 'package:meta/meta.dart';

/// Что главное меню узнаёт при запуске.
@immutable
final class MenuInfo {
  /// Создаёт сведения.
  const MenuInfo({required this.appVersion, required this.packVersion, this.starterDecksError});

  /// Версия приложения; `null`, если узнать её не удалось (на игру это не влияет).
  final String? appVersion;

  /// Версия набора карт; `null`, если набор не прошёл проверку.
  final int? packVersion;

  /// Ошибка, с которой не удалось подарить стартовые колоды; `null`, если всё прошло. Набор карт от неё не зависит.
  final Object? starterDecksError;

  /// Набор карт загружен и проверен.
  bool get contentAvailable => packVersion != null;
}

/// Сценарий: подготовить приложение к первому показу меню.
///
/// Загружает набор карт, дарит каждой фракции стартовую колоду, если у неё колод нет, и называет версии приложения
/// и набора карт. Сбой чтения версии приложения или подарка колод не делает набор «недоступным»: он возвращается в
/// сведениях, а меню остаётся рабочим.
final class LoadMenu {
  /// Создаёт сценарий.
  const LoadMenu(this._appInfo, this._loadGameContent, this._ensureStarterDecks);

  final AppInfo _appInfo;
  final LoadGameContent _loadGameContent;
  final EnsureStarterDecks _ensureStarterDecks;

  /// Готовит меню.
  Future<MenuInfo> call() async {
    String? appVersion;
    try {
      appVersion = await _appInfo.version();
    } on Object {
      // Версия нужна только для подписи в меню.
      appVersion = null;
    }
    switch (await _loadGameContent()) {
      case GameContentReady(:final content):
        Object? starterDecksError;
        try {
          await _ensureStarterDecks();
        } on Object catch (error) {
          starterDecksError = error;
        }
        return MenuInfo(
          appVersion: appVersion,
          packVersion: content.pack.manifest.packVersion,
          starterDecksError: starterDecksError,
        );
      case GameContentRejected():
        return MenuInfo(appVersion: appVersion, packVersion: null);
    }
  }
}
