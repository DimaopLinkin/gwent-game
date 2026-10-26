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

  /// История партий.
  static const String history = '/history';

  /// Параметр пути реплея: идентификатор партии в истории.
  static const String replayIdParam = 'id';

  /// Реплей партии [recordId] из истории.
  static String replay(String recordId) => '$history/${Uri.encodeComponent(recordId)}';

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

  /// «Первая партия»: обучение (ADR 0034).
  static const String tutorial = '/tutorial';

  /// Параметр адреса обучения: «Первая партия» открыта из кампании (миссия 0), выход ведёт на тропу.
  static const String fromCampaignParam = 'campaign';

  /// «Первая партия» как миссия 0 кампании: выход и итог ведут на тропу.
  static const String tutorialFromCampaign = '$tutorial?$fromCampaignParam=1';

  /// Тропа кампании «Тропа ведьмака» (ADR 0033).
  static const String campaign = '/campaign';

  /// Выбор колоды кампании («Колода для боя»).
  static const String campaignDecks = '$campaign/decks';

  /// Параметр адреса выбора колоды: узел, в бой на который идёт игрок.
  static const String campaignNodeParam = 'node';

  /// Выбор колоды перед боем на узле [nodeId].
  static String campaignDecksFor(String nodeId) => '$campaignDecks?$campaignNodeParam=${Uri.encodeComponent(nodeId)}';

  /// Конструктор новой колоды в режиме кампании.
  static const String campaignDeckNew = '$campaignDecks/new';

  /// Параметр пути партии узла: идентификатор узла.
  static const String campaignNodeIdParam = 'nodeId';

  /// Партия узла [nodeId] кампании.
  static String campaignPlay(String nodeId) => '$campaign/play/${Uri.encodeComponent(nodeId)}';

  /// Настройки.
  static const String settings = '/settings';

  /// Настройки поверх идущей партии: из них нельзя запустить «Первую партию».
  static const String settingsOverGame = '$settings?$overGameParam=1';

  /// Справочник «Как играть»: список тем.
  static const String howToPlayPath = '/how-to-play';

  /// Параметр адреса темы справочника.
  static const String howToTopicParam = 'topic';

  /// Параметр адреса: справочник открыт поверх партии, поэтому кнопки «Пройти первую партию» в нём нет.
  static const String overGameParam = 'overGame';

  /// Список тем справочника; [overGame] — открыт поверх идущей партии.
  static String howToPlay({bool overGame = false}) => overGame ? '$howToPlayPath?$overGameParam=1' : howToPlayPath;

  /// Страница темы справочника [topicKey].
  static String howToTopic(String topicKey) => '$howToPlayPath/${Uri.encodeComponent(topicKey)}';

  /// Параметр пути партии: режим, `hotSeat` или `bot`.
  static const String matchModeParam = 'mode';

  /// Путь партии на одном телефоне.
  static const String matchHotSeat = '$match?$matchModeParam=hotSeat';

  /// Путь партии против бота.
  static const String matchBot = '$match?$matchModeParam=bot';
}
