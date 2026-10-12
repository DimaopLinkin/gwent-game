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
