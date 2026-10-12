import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';

/// Колоды с таким идентификатором нет.
final class DeckNotFoundException implements Exception {
  /// Создаёт ошибку для колоды [deckId].
  const DeckNotFoundException(this.deckId);

  /// Идентификатор, по которому колоду искали.
  final String deckId;

  @override
  String toString() => 'DeckNotFoundException: нет колоды $deckId';
}

/// Колода нарушает правила сборки и не может идти в партию.
final class InvalidDeckException implements Exception {
  /// Создаёт ошибку для колоды [deckId] с проблемами [issues].
  InvalidDeckException(this.deckId, List<DeckIssue> issues) : issues = List.unmodifiable(issues);

  /// Идентификатор колоды.
  final String deckId;

  /// Все проблемы колоды, список не пуст.
  final List<DeckIssue> issues;

  @override
  String toString() => 'InvalidDeckException: колода $deckId, $issues';
}

/// Фракции нет в пакете контента или из неё нельзя собрать колоду (например, «Общий»).
final class NotADeckFactionException implements Exception {
  /// Создаёт ошибку для фракции [factionId].
  const NotADeckFactionException(this.factionId);

  /// UUID фракции.
  final String factionId;

  @override
  String toString() => 'NotADeckFactionException: из фракции $factionId колоду не собрать';
}
