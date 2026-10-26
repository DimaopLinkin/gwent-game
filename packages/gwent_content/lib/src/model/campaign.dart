/// Вид узла кампании (`kind` в `campaign.json`).
enum NodeKind {
  /// Сценарная партия («Первая партия»): ходы заданы заранее, колоды противника нет.
  scripted('scripted'),

  /// Обычная партия основного пути.
  duel('duel'),

  /// «Заказ»: проходится в любое время после указанного узла, ничего не открывает.
  order('order'),

  /// Босс главы.
  boss('boss'),

  /// Партия турнира «Высокие ставки».
  tournament('tournament')
  ;

  const NodeKind(this.key);

  /// Ключ в данных.
  final String key;

  /// Вид по ключу или `null`.
  static NodeKind? fromKey(String key) {
    for (final kind in values) {
      if (kind.key == key) return kind;
    }
    return null;
  }
}

/// Уровень сложности бота узла. Соответствует `BotDifficulty` приложения (ADR 0021), но пакет контента от него
/// не зависит.
enum CampaignDifficulty {
  /// Лёгкий.
  easy('easy'),

  /// Нормальный.
  normal('normal'),

  /// Тяжёлый.
  hard('hard'),

  /// «НА СМЕРТЬ!».
  deathMatch('death_match')
  ;

  const CampaignDifficulty(this.key);

  /// Ключ в данных.
  final String key;

  /// Уровень по ключу или `null`.
  static CampaignDifficulty? fromKey(String key) {
    for (final difficulty in values) {
      if (difficulty.key == key) return difficulty;
    }
    return null;
  }
}

/// Условие дополнительной награды. Считает его код приложения по итогу партии и журналу (ADR 0033); данные
/// только называют условие.
enum BonusCondition {
  /// Выиграть партию 2:0: в двух раундах, без проигранных и ничейных.
  winTwoZero('win_2_0'),

  /// Не сыграть ни одной особой карты.
  noSpecials('no_specials'),

  /// Выиграть раунд с перевесом не меньше 20 очков.
  margin20('margin_20')
  ;

  const BonusCondition(this.key);

  /// Ключ в данных.
  final String key;

  /// Условие по ключу или `null`.
  static BonusCondition? fromKey(String key) {
    for (final condition in values) {
      if (condition.key == key) return condition;
    }
    return null;
  }
}

/// Карта или лидер в награде или в колоде противника: UUID и число копий.
final class CardGrant {
  /// Создаёт запись о [copies] копиях карты [cardId].
  const CardGrant({required this.cardId, required this.copies});

  /// UUID карты отряда, особой карты или лидера.
  final String cardId;

  /// Сколько копий.
  final int copies;
}

/// Дополнительная награда за условие.
final class CampaignBonus {
  /// Создаёт бонус.
  CampaignBonus({required this.condition, required List<CardGrant> reward}) : reward = List.unmodifiable(reward);

  /// Условие.
  final BonusCondition condition;

  /// Что выдаётся за условие.
  final List<CardGrant> reward;
}

/// Соперник узла.
final class CampaignOpponent {
  /// Создаёт соперника. У сценарного узла есть только имя.
  CampaignOpponent({required this.nameKey, this.fractionId, this.leaderId, List<CardGrant> deck = const []})
    : deck = List.unmodifiable(deck);

  /// Ключ строки с именем соперника.
  final String nameKey;

  /// UUID фракции соперника; `null` у сценарного узла.
  final String? fractionId;

  /// UUID лидера соперника; `null` у сценарного узла.
  final String? leaderId;

  /// Фиксированная колода (карты без лидера); пуста у сценарного узла.
  final List<CardGrant> deck;
}

/// Узел кампании: одна партия.
final class CampaignNode {
  /// Создаёт узел.
  CampaignNode({
    required this.id,
    required this.kind,
    required this.afterId,
    required this.opponent,
    required this.difficulty,
    required this.themeKey,
    required this.scenario,
    required List<CardGrant> reward,
    required this.bonus,
  }) : reward = List.unmodifiable(reward);

  /// Идентификатор узла, например `c1-03`. Не меняется никогда: на него ссылается прогресс игрока.
  final String id;

  /// Вид.
  final NodeKind kind;

  /// Узел, победой в котором открывается этот; `null` только у первого узла кампании.
  final String? afterId;

  /// Соперник.
  final CampaignOpponent opponent;

  /// Уровень бота.
  final CampaignDifficulty difficulty;

  /// Ключ строки с темой колоды.
  final String themeKey;

  /// Имя сценария сценарной партии; `null` у остальных узлов.
  final String? scenario;

  /// Награда за первую победу.
  final List<CardGrant> reward;

  /// Условие и дополнительная награда или `null`.
  final CampaignBonus? bonus;

  /// Это сценарная партия.
  bool get isScripted => kind == NodeKind.scripted;
}

/// Глава кампании.
final class CampaignChapter {
  /// Создаёт главу.
  CampaignChapter({
    required this.id,
    required this.number,
    required this.nameKey,
    required this.released,
    required List<CampaignNode> nodes,
  }) : nodes = List.unmodifiable(nodes);

  /// Идентификатор, например `c1`.
  final String id;

  /// Номер главы с единицы.
  final int number;

  /// Ключ строки с названием.
  final String nameKey;

  /// Глава выпущена: в её узлах можно играть. Невыпущенные главы показываются закрытыми.
  final bool released;

  /// Узлы в порядке прохождения.
  final List<CampaignNode> nodes;
}

/// Колода, которую игрок получает вместе со стартовым набором.
final class StarterDeck {
  /// Создаёт описание стартовой колоды.
  const StarterDeck({required this.nameKey, required this.leaderId});

  /// Ключ строки с названием колоды.
  final String nameKey;

  /// Лидер колоды; его выдаёт награда первого узла.
  final String leaderId;
}

/// Каталог кампании (`campaign.json`): главы, узлы, награды и колоды противников.
final class CampaignCatalog {
  /// Создаёт каталог.
  CampaignCatalog({required this.formatVersion, required this.starterDeck, required List<CampaignChapter> chapters})
    : chapters = List.unmodifiable(chapters);

  /// Версия формата каталога.
  final int formatVersion;

  /// Колода, которая создаётся вместе со стартовым набором.
  final StarterDeck starterDeck;

  /// Главы по порядку.
  final List<CampaignChapter> chapters;

  /// Все узлы по порядку глав.
  late final List<CampaignNode> nodes = List.unmodifiable([for (final chapter in chapters) ...chapter.nodes]);

  /// Узлы по идентификатору.
  late final Map<String, CampaignNode> nodesById = {for (final node in nodes) node.id: node};

  /// Глава, в которой лежит узел [nodeId], или `null`.
  CampaignChapter? chapterOf(String nodeId) {
    for (final chapter in chapters) {
      if (chapter.nodes.any((node) => node.id == nodeId)) return chapter;
    }
    return null;
  }

  /// Первый узел кампании («Первая партия»).
  CampaignNode get firstNode => nodes.first;
}
