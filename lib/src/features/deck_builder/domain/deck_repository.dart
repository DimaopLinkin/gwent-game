import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';

/// Хранилище колод игрока и его выбора активной колоды каждой фракции.
abstract interface class DeckRepository {
  /// Все колоды, сначала недавно изменённые. Поток выдаёт новый список после каждого изменения.
  Stream<List<Deck>> watchAll();

  /// Колоды фракции [factionId], сначала недавно изменённые.
  Future<List<Deck>> findByFaction(String factionId);

  /// Колода по идентификатору или `null`, если её нет.
  Future<Deck?> findById(String id);

  /// Создаёт колоду или полностью заменяет существующую с тем же идентификатором.
  ///
  /// Если у колоды сменилась фракция, она перестаёт быть активной колодой прежней фракции. С [activate] колода
  /// в том же изменении становится активной колодой своей фракции.
  Future<void> save(Deck deck, {bool activate = false});

  /// Удаляет колоду. Удаление отсутствующей колоды ничего не делает.
  ///
  /// Если колода была активной, её фракция остаётся без активной колоды.
  Future<void> delete(String id);

  /// Активные колоды: UUID фракции и идентификатор колоды. Поток выдаёт новый словарь после каждого изменения.
  Stream<Map<String, String>> watchActiveDeckIds();

  /// Идентификатор активной колоды фракции [factionId] или `null`, если она не выбрана.
  Future<String?> findActiveDeckId(String factionId);

  /// Делает колоду [deckId] активной колодой фракции, с которой она сохранена.
  ///
  /// Бросает [DeckNotFoundException], если колоды нет.
  Future<void> setActive(String deckId);
}
