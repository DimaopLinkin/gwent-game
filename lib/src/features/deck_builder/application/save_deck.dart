import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/core/domain/id_generator.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';

/// Сценарий: сохранить колоду.
///
/// Новой колоде (без [id]) выдаётся идентификатор; время изменения ставится в момент сохранения.
final class SaveDeck {
  /// Создаёт сценарий.
  const SaveDeck(this._repository, this._clock, this._ids);

  final DeckRepository _repository;
  final Clock _clock;
  final IdGenerator _ids;

  /// Сохраняет колоду и возвращает её в сохранённом виде.
  Future<Deck> call({
    String? id,
    required String name,
    required String factionId,
    required String leaderId,
    required Map<String, int> cards,
  }) async {
    final deck = Deck(
      id: id ?? _ids.next(),
      name: name,
      factionId: factionId,
      leaderId: leaderId,
      cards: cards,
      updatedAt: _clock.now(),
    );
    await _repository.save(deck);
    return deck;
  }
}
