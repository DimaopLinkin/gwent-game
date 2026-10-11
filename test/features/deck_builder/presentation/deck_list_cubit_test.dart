import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_state.dart';

import '../../../support/factories.dart';
import '../../../support/fakes.dart';

void main() {
  test('сначала загрузка, затем колоды и их изменения', () async {
    final repository = InMemoryDeckRepository();
    final cubit = DeckListCubit(WatchDecks(repository));
    addTearDown(cubit.close);

    expect(cubit.state, isA<DeckListLoading>());
    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<DeckListLoaded>().having((state) => state.decks, 'decks', isEmpty),
        isA<DeckListLoaded>().having((state) => state.decks, 'decks', [testDeck()]),
      ]),
    );
    await pumpEventQueue();
    await repository.save(testDeck());
    await expectation;
  });

  test('ошибка чтения переводит в состояние ошибки', () async {
    final failure = Exception('база недоступна');
    final repository = InMemoryDeckRepository()..watchError = failure;
    final cubit = DeckListCubit(WatchDecks(repository));
    addTearDown(cubit.close);

    await expectLater(
      cubit.stream,
      emits(isA<DeckListFailed>().having((state) => state.error, 'error', failure)),
    );
  });
}
