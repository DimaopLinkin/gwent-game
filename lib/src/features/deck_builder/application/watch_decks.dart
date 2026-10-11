import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';

/// Сценарий: следить за списком колод игрока.
final class WatchDecks {
  /// Создаёт сценарий над [repository].
  const WatchDecks(this._repository);

  final DeckRepository _repository;

  /// Список колод, сначала недавно изменённые.
  Stream<List<Deck>> call() => _repository.watchAll();
}
