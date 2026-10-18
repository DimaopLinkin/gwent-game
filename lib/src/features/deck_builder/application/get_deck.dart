import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';

/// Сценарий: открыть сохранённую колоду для правки.
final class GetDeck {
  /// Создаёт сценарий.
  const GetDeck(this._repository);

  final DeckRepository _repository;

  /// Колода с идентификатором [id] или `null`, если её нет (например, удалена).
  Future<Deck?> call(String id) => _repository.findById(id);
}
