import 'package:drift/drift.dart';

/// Колоды игрока. Состав колоды лежит в [DeckCards].
@DataClassName('DeckRow')
class Decks extends Table {
  /// Идентификатор колоды (UUID).
  TextColumn get id => text()();

  /// Название, которое дал игрок.
  TextColumn get name => text()();

  /// UUID фракции из пакета контента.
  TextColumn get factionId => text()();

  /// UUID карты лидера из пакета контента.
  TextColumn get leaderId => text()();

  /// Момент последнего сохранения.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Карты колоды: UUID карты и число копий.
@DataClassName('DeckCardRow')
class DeckCards extends Table {
  /// Колода; при её удалении строки удаляются каскадно.
  TextColumn get deckId => text().references(Decks, #id, onDelete: KeyAction.cascade)();

  /// UUID карты из пакета контента.
  TextColumn get cardId => text()();

  /// Число копий, больше нуля.
  IntColumn get copies => integer()();

  @override
  Set<Column<Object>> get primaryKey => {deckId, cardId};

  @override
  List<String> get customConstraints => ['CHECK (copies > 0)'];
}
