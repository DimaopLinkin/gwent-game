import 'package:gwent_content/gwent_content.dart' show ContentPack, ValidationIssue;
import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Контент, готовый к партии: проверенный пакет и то, что из него получил движок.
///
/// Пакет нужен интерфейсу (названия, тексты, фракции по UUID), справочник и параметры партии — движку.
@immutable
final class GameContent {
  /// Создаёт контент.
  GameContent({
    required this.pack,
    required this.catalog,
    required this.rules,
    required Map<String, Faction> factions,
  }) : factions = Map.unmodifiable(factions);

  /// Проверенный пакет контента.
  final ContentPack pack;

  /// Справочник карт и лидеров для движка.
  final CardCatalog catalog;

  /// Числовые параметры партии и колоды из таблицы `game_rules` пакета.
  final GameRules rules;

  /// Фракция движка по UUID фракции пакета, включая нейтральную («Общий»).
  final Map<String, Faction> factions;
}

/// Итог получения контента для партии.
sealed class GameContentResult {
  const GameContentResult();
}

/// Контент готов.
final class GameContentReady extends GameContentResult {
  /// Создаёт успешный итог.
  const GameContentReady(this.content);

  /// Контент для партии.
  final GameContent content;
}

/// Контент недоступен: пакет не прошёл проверку или его данные не подходят движку.
final class GameContentRejected extends GameContentResult {
  /// Создаёт итог с проблемами [issues].
  GameContentRejected(List<ValidationIssue> issues) : issues = List.unmodifiable(issues);

  /// Проблемы; не пустой список.
  final List<ValidationIssue> issues;
}
