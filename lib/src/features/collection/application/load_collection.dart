import 'package:gwent/src/features/collection/domain/collection_repository.dart';
import 'package:gwent/src/features/collection/domain/owned_cards.dart';

/// Сценарий: какие карты открыты игроком в кампании.
final class LoadCollection {
  /// Создаёт сценарий над [repository].
  const LoadCollection(this._repository);

  final CollectionRepository _repository;

  /// Коллекция сейчас; пустая, пока игрок не открыл ни одной карты.
  Future<CardCollection> call() => _repository.load();
}
