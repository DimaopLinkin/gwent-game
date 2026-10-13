import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';
import 'package:gwent_content/gwent_content.dart' show ContentPack;
import 'package:gwent_engine/gwent_engine.dart';

/// Объясняет игроку, почему колода не годится: короткая фраза для подсказки под списком или счётчиками.
///
/// Названия карт берутся из строк пакета по UUID. Одну и ту же фразу видят экран выбора колоды перед партией
/// и конструктор колоды.
final class DeckIssueText {
  /// Создаёт объяснение над пакетом [pack] и строками интерфейса [l10n].
  const DeckIssueText({required this.pack, required this.l10n});

  /// Пакет контента: названия карт.
  final ContentPack pack;

  /// Строки интерфейса.
  final AppLocalizations l10n;

  /// Фраза о проблеме [issue].
  String describe(DeckIssue issue) => switch (issue) {
    LeaderOfOtherFaction() => l10n.deckIssueLeaderOfOtherFaction,
    DeckRuleViolation(:final violation) => _violation(violation),
  };

  /// Фраза о первой проблеме списка или `null`, если колода годится.
  String? firstOf(List<DeckIssue> issues) => issues.isEmpty ? null : describe(issues.first);

  String _violation(DeckViolation violation) => switch (violation) {
    UnknownLeader() || LeaderNotDeckFaction() => l10n.deckIssueLeaderUnavailable,
    UnknownCard() => l10n.deckIssueUnknownCard,
    WrongFaction(:final card) => l10n.deckIssueWrongFaction(_cardName(card)),
    CreatedCardInDeck(:final card) => l10n.deckIssueCreatedCard(_cardName(card)),
    TooManyCopies(:final card, :final count, :final max) => l10n.deckIssueTooManyCopies(_cardName(card), count, max),
    TooFewUnitCards(:final count, :final min) => l10n.deckIssueTooFewUnits(min, count),
    TooManySpecialCards(:final count, :final max) => l10n.deckIssueTooManySpecials(max, count),
  };

  String _cardName(CardId card) {
    final rules = pack.rules;
    final key = rules.squadCardsById[card.value]?.nameKey ?? rules.specialCardsById[card.value]?.nameKey;
    return key == null ? card.value : pack.text(key);
  }
}
