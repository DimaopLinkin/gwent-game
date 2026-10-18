/// Пути экранов. Вложенность путей задаёт стек: «назад» с любого экрана ведёт в меню.
abstract final class AppRoutes {
  /// Главное меню.
  static const String menu = '/';

  /// Список колод.
  static const String decks = '/decks';

  /// Конструктор новой колоды.
  static const String deckNew = '$decks/new';

  /// Параметр пути конструктора: идентификатор колоды.
  static const String deckIdParam = 'id';

  /// Конструктор колоды с идентификатором [deckId].
  static String deckEdit(String deckId) => '$decks/${Uri.encodeComponent(deckId)}';

  /// Лобби сетевой игры.
  static const String lobby = '/lobby';

  /// Игровое поле.
  static const String match = '/match';

  /// Настройки.
  static const String settings = '/settings';

  /// Параметр пути партии: режим, `hotSeat` или `bot`.
  static const String matchModeParam = 'mode';

  /// Путь партии на одном телефоне.
  static const String matchHotSeat = '$match?$matchModeParam=hotSeat';

  /// Путь партии против бота.
  static const String matchBot = '$match?$matchModeParam=bot';
}
