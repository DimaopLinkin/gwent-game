/// Пути экранов. Вложенность путей задаёт стек: «назад» с любого экрана ведёт в меню.
abstract final class AppRoutes {
  /// Главное меню.
  static const String menu = '/';

  /// Конструктор колоды.
  static const String decks = '/decks';

  /// Лобби сетевой игры.
  static const String lobby = '/lobby';

  /// Игровое поле.
  static const String match = '/match';
}
