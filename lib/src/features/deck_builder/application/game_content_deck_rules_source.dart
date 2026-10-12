import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';

/// Правила колод по контенту для партии: тот же пакет и тот же справочник движка, что у партии.
final class GameContentDeckRulesSource implements DeckRulesSource {
  /// Создаёт источник над сценарием [loadGameContent].
  GameContentDeckRulesSource(this._loadGameContent);

  final LoadGameContent _loadGameContent;
  (GameContent, DeckRules)? _last;

  /// Бросает [DeckRulesUnavailableException], если пакет контента не прошёл проверку.
  @override
  Future<DeckRules> load() async => switch (await _loadGameContent()) {
    GameContentReady(:final content) => _rulesFor(content),
    GameContentRejected(:final issues) => throw DeckRulesUnavailableException(issues),
  };

  /// Правила строятся заново только при смене контента: `LoadGameContent` отдаёт один и тот же объект.
  DeckRules _rulesFor(GameContent content) {
    if (_last case (final cached, final rules) when identical(cached, content)) return rules;
    final rules = DeckRules(pack: content.pack, catalog: content.catalog, gameRules: content.rules);
    _last = (content, rules);
    return rules;
  }
}
