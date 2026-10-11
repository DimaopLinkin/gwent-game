import 'package:gwent/src/features/deck_builder/domain/deck.dart';

/// Хранилище колод игрока.
abstract interface class DeckRepository {
  /// Все колоды, сначала недавно изменённые. Поток выдаёт новый список после каждого изменения.
  Stream<List<Deck>> watchAll();

  /// Колода по идентификатору или `null`, если её нет.
  Future<Deck?> findById(String id);

  /// Создаёт колоду или полностью заменяет существующую с тем же идентификатором.
  Future<void> save(Deck deck);

  /// Удаляет колоду. Удаление отсутствующей колоды ничего не делает.
  Future<void> delete(String id);
}
