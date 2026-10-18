import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/application/get_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/application/save_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_state.dart';

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/fakes.dart';

final class _BrokenRulesSource implements DeckRulesSource {
  @override
  Future<DeckRules> load() async => throw StateError('набор карт не загрузился');
}

void main() {
  late InMemoryDeckRepository repository;

  setUp(() => repository = InMemoryDeckRepository());

  Future<DeckEditorCubit> open({String? deckId, DeckRulesSource? source}) async {
    final cubit = DeckEditorCubit(
      loadDeckRules: LoadDeckRules(source ?? FakeDeckRulesSource()),
      getDeck: GetDeck(repository),
      saveDeck: SaveDeck(repository, FakeClock(DateTime.utc(2026, 10, 18)), SequentialIdGenerator()),
      newDeckName: 'Новая колода',
      deckId: deckId,
    );
    addTearDown(cubit.close);
    await cubit.stream.firstWhere((state) => state is! DeckEditorLoading);
    return cubit;
  }

  DeckEditorReady ready(DeckEditorCubit cubit) => cubit.state as DeckEditorReady;

  group('открытие', () {
    test('новая колода: первая фракция, без лидера и карт, открыта коллекция', () async {
      final cubit = await open();

      final state = ready(cubit);
      expect(state.faction.id, Small.skellige);
      expect(state.draft.name, 'Новая колода');
      expect(state.draft.leaderId, isNull);
      expect(state.draft.cards, isEmpty);
      expect(state.tab, DeckEditorTab.collection);
      expect(state.isValid, isFalse);
    });

    test('сохранённая колода открывается на вкладке «Колода» со своим составом', () async {
      await repository.save(smallSkelligeDeck());

      final state = ready(await open(deckId: 'deck-skellige'));

      expect(state.tab, DeckEditorTab.deck);
      expect(state.draft.id, 'deck-skellige');
      expect(state.draft.leaderId, Small.crach);
      expect(state.stats.total, 6);
      expect(state.isValid, isTrue);
    });

    test('колоды нет в хранилище — состояние «не найдена»', () async {
      final cubit = await open(deckId: 'нет-такой');

      expect(cubit.state, isA<DeckEditorNotFound>());
    });

    test('набор карт не загрузился — состояние ошибки', () async {
      final cubit = await open(source: _BrokenRulesSource());

      expect(cubit.state, isA<DeckEditorFailed>());
    });
  });

  group('состав', () {
    test('добавление и удаление карт меняет счётчики и вкладки', () async {
      final cubit = await open();

      cubit
        ..addCard(Small.warrior)
        ..addCard(Small.warrior)
        ..addCard(Small.cerys)
        ..addCard(Small.frost);
      var state = ready(cubit);
      expect(state.stats.total, 4);
      expect(state.stats.units, 3);
      expect(state.stats.specials, 1);
      expect(state.stats.heroes, 1);
      expect(state.lastMoved, Small.frost);
      expect(state.moveSerial, 4);
      expect(state.visible.map((entry) => entry.card.id), contains(Small.mardroeme));

      cubit
        ..selectTab(DeckEditorTab.deck)
        ..removeCard(Small.warrior);
      state = ready(cubit);
      expect(state.visible.map((entry) => entry.card.id), [Small.warrior, Small.cerys, Small.frost]);
      expect(state.draft.copiesOf(Small.warrior), 1);
    });

    test('все копии в колоде: карта заблокирована, в подсказке причина, через время она гаснет', () async {
      final cubit = await open();
      cubit
        ..addCard(Small.geralt)
        ..addCard(Small.geralt);

      var state = ready(cubit);
      expect(state.draft.copiesOf(Small.geralt), 1);
      expect(state.message, const EditorMessage(AddRefusal.allCopiesInDeck, max: 2));
      expect(state.collection.firstWhere((entry) => entry.card.id == Small.geralt).blocked, isTrue);

      await Future<void>.delayed(DeckEditorCubit.messageDuration + const Duration(milliseconds: 100));
      state = ready(cubit);
      expect(state.message, isNull);
    });

    test('особых карт не больше предела из правил', () async {
      final cubit = await open();
      cubit
        ..addCard(Small.frost)
        ..addCard(Small.horn)
        ..addCard(Small.mardroeme);

      final state = ready(cubit);
      expect(state.stats.specials, smallGameRules.maxSpecialCards);
      expect(state.message, const EditorMessage(AddRefusal.specialLimit, max: 2));
      expect(state.availableCount, lessThan(state.collection.length));
    });

    test('героя можно положить только один раз', () async {
      final cubit = await open();
      cubit
        ..addCard(Small.cerys)
        ..addCard(Small.cerys);

      expect(ready(cubit).draft.copiesOf(Small.cerys), 1);
    });

    test('неизвестную карту и карту, которой нет в колоде, не трогаем', () async {
      final cubit = await open();
      final before = ready(cubit);

      cubit
        ..addCard('нет-такой')
        ..removeCard(Small.warrior);

      expect(ready(cubit).moveSerial, before.moveSerial);
    });
  });

  group('фильтры', () {
    test('фильтр по виду карт и «Только доступные»', () async {
      final cubit = await open();
      cubit
        ..addCard(Small.frost)
        ..addCard(Small.horn)
        ..selectFilter(CardFilter.weather);

      expect(ready(cubit).visible.map((entry) => entry.card.id), [Small.frost]);

      cubit
        ..selectFilter(CardFilter.special)
        ..toggleOnlyAvailable();
      expect(ready(cubit).visible.map((entry) => entry.card.id), isNot(contains(Small.horn)));
      expect(ready(cubit).onlyAvailable, isTrue);

      cubit.selectFilter(CardFilter.hero);
      expect(ready(cubit).visible.map((entry) => entry.card.id), [Small.cerys]);
    });
  });

  group('лидер и фракция', () {
    test('лидер выбирается из своей фракции; чужой отвергается', () async {
      final cubit = await open();

      cubit.selectLeader(Small.eredin);
      expect(ready(cubit).draft.leaderId, isNull);

      cubit.selectLeader(Small.bran);
      expect(ready(cubit).draft.leaderId, Small.bran);
      expect(ready(cubit).leader?.id, Small.bran);
    });

    test('смена фракции пустой колоды без лидера идёт без вопросов', () async {
      final cubit = await open();

      final change = cubit.changeFaction(1);

      expect(change, isNull);
      expect(ready(cubit).faction.id, Small.monsters);
    });

    test('смена фракции готовой колоды ждёт подтверждения, чужие карты уходят, нейтральные остаются', () async {
      await repository.save(smallSkelligeDeck());
      final cubit = await open(deckId: 'deck-skellige');

      final change = cubit.changeFaction(1);

      expect(change, const FactionChange(target: 1, removed: 4));
      expect(ready(cubit).faction.id, Small.skellige, reason: 'пока не подтверждено, фракция прежняя');

      cubit.applyFactionChange(change!);
      final state = ready(cubit);
      expect(state.faction.id, Small.monsters);
      expect(state.draft.leaderId, isNull);
      expect(state.draft.cards, {Small.geralt: 1, Small.frost: 1});
      expect(state.tab, DeckEditorTab.collection);
    });

    test('стрелки идут по кругу', () async {
      final cubit = await open();

      cubit.changeFaction(-1);

      expect(ready(cubit).faction.id, Small.monsters);
    });
  });

  group('сохранение', () {
    test('готовая колода сохраняется и экран закрывается', () async {
      final cubit = await open();
      cubit
        ..selectLeader(Small.crach)
        ..rename('  Моя колода  ')
        ..addCard(Small.warrior)
        ..addCard(Small.warrior)
        ..addCard(Small.warrior)
        ..addCard(Small.cerys)
        ..addCard(Small.geralt);
      expect(ready(cubit).isValid, isTrue);

      await cubit.save();

      expect(cubit.state, isA<DeckEditorSaved>());
      final saved = (await repository.watchAll().first).single;
      expect(saved.id, 'id-1');
      expect(saved.name, 'Моя колода');
      expect(saved.leaderId, Small.crach);
      expect(saved.cards, {Small.warrior: 3, Small.cerys: 1, Small.geralt: 1});
    });

    test('колода, нарушающая правила, сохраняется черновиком', () async {
      final cubit = await open();
      cubit
        ..selectLeader(Small.crach)
        ..addCard(Small.warrior);
      expect(ready(cubit).isValid, isFalse);
      expect(ready(cubit).tooFewUnits, isTrue);

      await cubit.save();

      expect(cubit.state, isA<DeckEditorSaved>());
      expect((await repository.watchAll().first).single.cards, {Small.warrior: 1});
    });

    test('колоду без лидера сохранить нельзя', () async {
      final cubit = await open();
      cubit.addCard(Small.warrior);

      await cubit.save();

      expect(cubit.state, isA<DeckEditorReady>());
      expect(await repository.watchAll().first, isEmpty);
    });

    test('пустое название заменяется названием по умолчанию; существующая колода сохраняется под своим id', () async {
      await repository.save(smallSkelligeDeck());
      final cubit = await open(deckId: 'deck-skellige');
      cubit.rename('   ');

      await cubit.save();

      final saved = (await repository.watchAll().first).single;
      expect(saved.id, 'deck-skellige');
      expect(saved.name, 'Новая колода');
    });

    test('сбой хранилища — состояние ошибки', () async {
      repository.saveError = StateError('диск полон');
      final cubit = await open();
      cubit
        ..selectLeader(Small.crach)
        ..addCard(Small.warrior);

      await cubit.save();

      expect(cubit.state, isA<DeckEditorFailed>());
    });
  });
}
