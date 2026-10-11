import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';

/// Сценарий: удалить колоду.
final class DeleteDeck {
  /// Создаёт сценарий над [repository].
  const DeleteDeck(this._repository);

  final DeckRepository _repository;

  /// Удаляет колоду с идентификатором [id], если она есть.
  Future<void> call(String id) => _repository.delete(id);
}
