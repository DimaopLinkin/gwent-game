import 'package:gwent/src/features/deck_builder/domain/deck.dart';

/// Состояние списка колод.
sealed class DeckListState {
  const DeckListState();
}

/// Колоды ещё читаются.
final class DeckListLoading extends DeckListState {
  /// Создаёт состояние.
  const DeckListLoading();
}

/// Колоды прочитаны.
final class DeckListLoaded extends DeckListState {
  /// Создаёт состояние со списком [decks].
  const DeckListLoaded(this.decks);

  /// Колоды, сначала недавно изменённые.
  final List<Deck> decks;
}

/// Колоды прочитать не удалось.
final class DeckListFailed extends DeckListState {
  /// Создаёт состояние с причиной [error].
  const DeckListFailed(this.error);

  /// Причина для журнала; игроку показывается общее сообщение.
  final Object error;
}
