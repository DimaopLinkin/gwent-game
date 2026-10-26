import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';
import 'package:meta/meta.dart';

/// Колода игрока с оценкой для кампании: годна ли она при открытых картах (ADR 0033).
@immutable
final class CampaignDeck {
  /// Создаёт запись: [issues] — все проблемы колоды по правилам сборки и по коллекции.
  CampaignDeck(this.deck, List<DeckIssue> issues) : issues = List.unmodifiable(issues);

  /// Колода.
  final Deck deck;

  /// Почему колода не годится для партии кампании; пусто, если годится.
  final List<DeckIssue> issues;

  /// С колодой можно идти в партию кампании.
  bool get isReady => issues.isEmpty;
}
