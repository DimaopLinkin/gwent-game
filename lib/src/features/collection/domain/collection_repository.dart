import 'package:gwent/src/features/collection/domain/owned_cards.dart';

/// Хранилище открытых карт игрока (ADR 0033).
abstract interface class CollectionRepository {
  /// Коллекция сейчас.
  Future<CardCollection> load();

  /// Коллекция; поток выдаёт новый снимок после каждого изменения.
  Stream<CardCollection> watch();

  /// Открывает карты: к числу открытых копий каждой карты из [copies] прибавляется указанное число.
  ///
  /// Предел копий (`count` карты в пакете) хранилище не знает: его держит сценарий выдачи награды.
  /// Бросает [ArgumentError], если для какой-то карты число копий меньше единицы; тогда не открывается ничего.
  Future<void> grant(Map<String, int> copies);
}
