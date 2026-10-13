import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';

/// Сценарий: правила сборки колод по активному пакету контента — фракции, лидеры, проверка колоды.
final class LoadDeckRules {
  /// Создаёт сценарий.
  const LoadDeckRules(this._rules);

  final DeckRulesSource _rules;

  /// Правила колод.
  ///
  /// Бросает `DeckRulesUnavailableException`, если пакет контента не прошёл проверку.
  Future<DeckRules> call() => _rules.load();
}
