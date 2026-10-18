import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/application/delete_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_state.dart';

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/factories.dart';
import '../../../support/fakes.dart';

final class _BrokenRulesSource implements DeckRulesSource {
  @override
  Future<DeckRules> load() async => throw StateError('набор карт не загрузился');
}

void main() {
  DeckListCubit cubitFor(InMemoryDeckRepository repository, {DeckRulesSource? source}) => DeckListCubit(
    WatchDecks(repository),
    LoadDeckRules(source ?? FakeDeckRulesSource()),
    DeleteDeck(repository),
  );

  test('сначала загрузка, затем колоды с правилами и их изменения', () async {
    final repository = InMemoryDeckRepository();
    final cubit = cubitFor(repository);
    addTearDown(cubit.close);

    expect(cubit.state, isA<DeckListLoading>());
    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<DeckListLoaded>()
            .having((state) => state.decks, 'decks', isEmpty)
            .having((state) => state.rules, 'rules', isNotNull),
        isA<DeckListLoaded>().having((state) => state.decks, 'decks', [testDeck()]),
      ]),
    );
    await pumpEventQueue();
    await repository.save(testDeck());
    await expectation;
  });

  test('без набора карт колоды всё равно видны, но без правил', () async {
    final repository = InMemoryDeckRepository([testDeck()]);
    final cubit = cubitFor(repository, source: _BrokenRulesSource());
    addTearDown(cubit.close);

    await expectLater(
      cubit.stream,
      emits(
        isA<DeckListLoaded>()
            .having((state) => state.decks, 'decks', [testDeck()])
            .having((state) => state.rules, 'rules', isNull),
      ),
    );
  });

  test('удаление убирает колоду из списка', () async {
    final repository = InMemoryDeckRepository([testDeck(), testDeck(id: 'deck-2')]);
    final cubit = cubitFor(repository);
    addTearDown(cubit.close);
    await cubit.stream.firstWhere((state) => state is DeckListLoaded);

    final expectation = expectLater(
      cubit.stream,
      emits(isA<DeckListLoaded>().having((state) => state.decks.map((deck) => deck.id), 'ids', ['deck-2'])),
    );
    await cubit.delete('deck-1');
    await expectation;
  });

  test('ошибка чтения переводит в состояние ошибки', () async {
    final failure = Exception('база недоступна');
    final repository = InMemoryDeckRepository()..watchError = failure;
    final cubit = cubitFor(repository);
    addTearDown(cubit.close);

    await expectLater(
      cubit.stream,
      emits(isA<DeckListFailed>().having((state) => state.error, 'error', failure)),
    );
  });
}
