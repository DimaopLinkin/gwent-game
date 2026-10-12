import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';

/// Сценарий: следить за выбором активных колод.
final class WatchActiveDecks {
  /// Создаёт сценарий над [repository].
  const WatchActiveDecks(this._repository);

  final DeckRepository _repository;

  /// UUID фракции и идентификатор её активной колоды. Фракции без выбранной колоды в словаре нет.
  Stream<Map<String, String>> call() => _repository.watchActiveDeckIds();
}
