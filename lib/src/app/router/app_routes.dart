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

  /// Игра на двух телефонах: выбор способа соединения.
  static const String play = '/play';

  /// Параметр пути `/play`: способ соединения, выбранный при открытии (`internet`); без него выбран Wi-Fi.
  static const String playMethodParam = 'method';

  /// Значение параметра способа соединения: через интернет.
  static const String playMethodInternet = 'internet';

  /// Игра на двух телефонах с выбранным способом «Через интернет»: туда возвращаются из онлайн-комнаты.
  static const String playInternet = '$play?$playMethodParam=$playMethodInternet';

  /// Создание сетевой игры (хост).
  static const String playCreate = '$play/create';

  /// Создание комнаты для игры через интернет (хост).
  static const String playOnlineCreate = '$play/online/create';

  /// Ввод кода комнаты для игры через интернет (гость).
  static const String playOnlineJoin = '$play/online/join';

  /// Поиск сетевой игры рядом (гость).
  static const String playFind = '$play/find';

  /// Сканер QR-кода партии (гость); возвращает адрес партии.
  static const String playFindScan = '$playFind/scan';

  /// Комната сетевой игры: ожидание соперника, выбор колоды, готовность.
  static const String playRoom = '$play/room';

  /// QR-код партии (хост).
  static const String playRoomQr = '$playRoom/qr';

  /// Выбор сохранённой колоды для комнаты.
  static const String playRoomDecks = '$playRoom/decks';

  /// Конструктор новой колоды из комнаты.
  static const String playRoomBuild = '$playRoom/build';

  /// Конструктор колоды [deckId] из комнаты.
  static String playRoomBuildDeck(String deckId) => '$playRoomBuild/${Uri.encodeComponent(deckId)}';

  /// Сетевая партия.
  static const String playMatch = '$play/match';

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
