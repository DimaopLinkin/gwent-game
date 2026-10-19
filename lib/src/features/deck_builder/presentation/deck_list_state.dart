import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';

/// Состояние списка колод.
sealed class DeckListState {
  const DeckListState();
}

/// Колоды читаются.
final class DeckListLoading extends DeckListState {
  /// Создаёт состояние.
  const DeckListLoading();
}

/// Колоды прочитаны.
final class DeckListLoaded extends DeckListState {
  /// Создаёт состояние: [decks] в порядке хранилища, [rules] — правила набора карт.
  const DeckListLoaded(this.decks, {this.rules});

  /// Сохранённые колоды.
  final List<Deck> decks;

  /// Правила по набору карт: фракции, лидеры, счётчики. `null`, если набор карт не загрузился; тогда у колод видны
  /// только название и число карт.
  final DeckRules? rules;
}

/// Не удалось прочитать колоды.
final class DeckListFailed extends DeckListState {
  /// Создаёт состояние с ошибкой [error].
  const DeckListFailed(this.error);

  /// Что пошло не так.
  final Object error;
}
