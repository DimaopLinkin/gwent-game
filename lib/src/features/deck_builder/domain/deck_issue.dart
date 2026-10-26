import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Почему колода не годится для партии.
@immutable
sealed class DeckIssue {
  const DeckIssue();
}

/// Нарушено правило сборки колоды из разделов 2.1–2.2 `docs/hand/main.md`; проверку делает движок.
final class DeckRuleViolation extends DeckIssue {
  /// Создаёт проблему из нарушения [violation].
  const DeckRuleViolation(this.violation);

  /// Нарушение по версии движка.
  final DeckViolation violation;

  @override
  bool operator ==(Object other) => other is DeckRuleViolation && other.violation == violation;

  @override
  int get hashCode => violation.hashCode;

  @override
  String toString() => 'DeckRuleViolation($violation)';
}

/// Лидер не из фракции колоды: колода сохранена с одной фракцией, а лидер взят у другой.
final class LeaderOfOtherFaction extends DeckIssue {
  /// Создаёт проблему для лидера [leaderId] фракции [leaderFactionId].
  const LeaderOfOtherFaction({required this.leaderId, required this.leaderFactionId});

  /// UUID карты лидера.
  final String leaderId;

  /// UUID фракции лидера.
  final String leaderFactionId;

  @override
  bool operator ==(Object other) =>
      other is LeaderOfOtherFaction && other.leaderId == leaderId && other.leaderFactionId == leaderFactionId;

  @override
  int get hashCode => Object.hash(leaderId, leaderFactionId);

  @override
  String toString() => 'LeaderOfOtherFaction($leaderId, $leaderFactionId)';
}

/// В колоде больше копий карты [cardId], чем открыто игроком в кампании (ADR 0033).
final class CardNotOwned extends DeckIssue {
  /// Создаёт проблему: в колоде [copies] копий, открыто [owned].
  const CardNotOwned({required this.cardId, required this.copies, required this.owned});

  /// UUID карты.
  final String cardId;

  /// Сколько копий в колоде.
  final int copies;

  /// Сколько копий открыто.
  final int owned;

  @override
  bool operator ==(Object other) =>
      other is CardNotOwned && other.cardId == cardId && other.copies == copies && other.owned == owned;

  @override
  int get hashCode => Object.hash(cardId, copies, owned);

  @override
  String toString() => 'CardNotOwned($cardId, в колоде $copies, открыто $owned)';
}

/// Лидер колоды ещё не открыт игроком в кампании (ADR 0033).
final class LeaderNotOwned extends DeckIssue {
  /// Создаёт проблему для лидера [leaderId].
  const LeaderNotOwned(this.leaderId);

  /// UUID карты лидера.
  final String leaderId;

  @override
  bool operator ==(Object other) => other is LeaderNotOwned && other.leaderId == leaderId;

  @override
  int get hashCode => leaderId.hashCode;

  @override
  String toString() => 'LeaderNotOwned($leaderId)';
}
