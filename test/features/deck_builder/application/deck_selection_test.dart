import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/application/ensure_starter_decks.dart';
import 'package:gwent/src/features/deck_builder/application/get_active_deck.dart';
import 'package:gwent/src/features/deck_builder/application/set_active_deck.dart';
import 'package:gwent/src/features/deck_builder/application/validate_deck.dart';
import 'package:gwent/src/features/deck_builder/application/watch_active_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/fakes.dart';

void main() {
  late InMemoryDeckRepository repository;
  late FakeDeckRulesSource rules;
  late FakeClock clock;
  late CreateStarterDeck createStarterDeck;
  late DeckSelectionLock lock;

  setUp(() {
    repository = InMemoryDeckRepository();
    rules = FakeDeckRulesSource();
    clock = FakeClock(DateTime.utc(2026, 10, 12, 9));
    createStarterDeck = CreateStarterDeck(repository, clock, SequentialIdGenerator());
    lock = DeckSelectionLock();
  });

  final invalidCards = {Small.warrior: 3};

  group('ValidateDeck', () {
    test('проверяет по правилам источника', () async {
      final validate = ValidateDeck(rules);

      expect(await validate(smallSkelligeDeck()), isEmpty);
      expect(await validate(smallSkelligeDeck(cards: invalidCards)), [
        const DeckRuleViolation(TooFewUnitCards(count: 3, min: 5)),
      ]);
    });
  });

  group('SetActiveDeck', () {
    late SetActiveDeck setActive;

    setUp(() => setActive = SetActiveDeck(repository, rules, lock));

    test('годная колода становится активной для своей фракции', () async {
      await repository.save(smallSkelligeDeck());

      await setActive('deck-skellige');

      expect(await repository.findActiveDeckId(Small.skellige), 'deck-skellige');
    });

    test('негодную колоду выбрать нельзя', () async {
      await repository.save(smallSkelligeDeck(cards: invalidCards));

      await expectLater(
        setActive('deck-skellige'),
        throwsA(isA<InvalidDeckException>().having((e) => e.issues, 'issues', isNotEmpty)),
      );
      expect(await repository.findActiveDeckId(Small.skellige), isNull);
    });

    test('несуществующую колоду выбрать нельзя', () async {
      await expectLater(setActive('нет такой'), throwsA(isA<DeckNotFoundException>()));
    });
  });

  group('CreateStarterDeck', () {
    test('сохраняет стартовую колоду и делает её активной', () async {
      final deck = await createStarterDeck(smallDeckRules, Small.skellige);

      expect(deck.id, 'id-1');
      expect(deck.updatedAt, clock.current);
      expect(await repository.findById('id-1'), deck);
      expect(await repository.findActiveDeckId(Small.skellige), 'id-1');
      expect(smallDeckRules.check(deck), isEmpty);
    });

    test('негодную стартовую колоду не сохраняет', () async {
      final strict = deckRulesFor(smallPack, gameRules: const GameRules(minUnitCards: 50, maxSpecialCards: 2));

      await expectLater(createStarterDeck(strict, Small.skellige), throwsA(isA<InvalidDeckException>()));
      expect(await repository.findByFaction(Small.skellige), isEmpty);
    });
  });

  group('EnsureStarterDecks', () {
    late EnsureStarterDecks ensure;

    setUp(() => ensure = EnsureStarterDecks(repository, rules, createStarterDeck, lock));

    test('создаёт стартовые колоды только фракциям без колод', () async {
      await repository.save(smallSkelligeDeck(cards: invalidCards));

      final created = await ensure();

      expect([for (final deck in created) deck.factionId], [Small.monsters]);
      expect(await repository.findByFaction(Small.skellige), hasLength(1));
      expect(await repository.findActiveDeckId(Small.monsters), created.single.id);
    });

    test('повторный вызов ничего не создаёт', () async {
      await ensure();

      expect(await ensure(), isEmpty);
    });
  });

  group('GetActiveDeck', () {
    late GetActiveDeck getActive;

    setUp(() => getActive = GetActiveDeck(repository, rules, createStarterDeck, lock));

    test('возвращает годную активную колоду', () async {
      final active = smallSkelligeDeck(id: 'active', updatedAt: DateTime.utc(2026, 10, 5));
      await repository.save(active);
      await repository.save(smallSkelligeDeck(id: 'newer', updatedAt: DateTime.utc(2026, 10, 6)));
      await repository.setActive(active.id);

      expect(await getActive(Small.skellige), active);
    });

    test('негодная активная колода уступает самой недавней годной', () async {
      final broken = smallSkelligeDeck(id: 'broken', cards: invalidCards, updatedAt: DateTime.utc(2026, 10, 7));
      final older = smallSkelligeDeck(id: 'older', updatedAt: DateTime.utc(2026, 10, 5));
      final newer = smallSkelligeDeck(id: 'newer', updatedAt: DateTime.utc(2026, 10, 6));
      for (final deck in [broken, older, newer]) {
        await repository.save(deck);
      }
      await repository.setActive(broken.id);

      expect(await getActive(Small.skellige), newer);
      expect(await repository.findActiveDeckId(Small.skellige), 'newer');
      expect(await repository.findById('broken'), broken, reason: 'негодная колода ждёт правки, а не удаляется');
    });

    test('без активной колоды выбирается годная колода фракции', () async {
      final deck = smallSkelligeDeck();
      await repository.save(deck);

      expect(await getActive(Small.skellige), deck);
      expect(await repository.findActiveDeckId(Small.skellige), deck.id);
    });

    test('без годных колод создаётся стартовая', () async {
      await repository.save(smallSkelligeDeck(cards: invalidCards));

      final deck = await getActive(Small.skellige);

      expect(deck.id, 'id-1');
      expect(smallDeckRules.check(deck), isEmpty);
      expect(await repository.findActiveDeckId(Small.skellige), 'id-1');
      expect(await getActive(Small.skellige), deck, reason: 'второй вызов не создаёт ещё одну колоду');
    });

    test('новый пакет сделал колоды негодными: стартовая колода, а прежние ждут правки', () async {
      final deck = smallSkelligeDeck();
      await repository.save(deck, activate: true);
      rules.rules = deckRulesFor(smallPack, gameRules: const GameRules(minUnitCards: 6, maxSpecialCards: 2));

      final active = await getActive(Small.skellige);

      expect(active.id, 'id-1');
      expect(rules.rules.check(active), isEmpty);
      expect(await repository.findById(deck.id), deck);
    });

    test('одновременные вызовы не задваивают стартовую колоду', () async {
      final ensureStarterDecks = EnsureStarterDecks(repository, rules, createStarterDeck, lock);
      repository.yieldOnRead = true;

      final results = await Future.wait([getActive(Small.skellige), getActive(Small.skellige)]);
      await Future.wait([ensureStarterDecks(), getActive(Small.monsters)]);

      expect(results.first, results.last);
      expect(await repository.findByFaction(Small.skellige), [results.first]);
      expect(await repository.findByFaction(Small.monsters), hasLength(1));
    });

    test('колода другой фракции не подходит', () async {
      await repository.save(smallSkelligeDeck());

      final deck = await getActive(Small.monsters);

      expect(deck.factionId, Small.monsters);
    });

    test('из нейтральной фракции колоду не собрать', () async {
      await expectLater(getActive(Small.common), throwsA(isA<NotADeckFactionException>()));
      expect(await repository.findByFaction(Small.common), isEmpty);
    });
  });

  group('WatchActiveDecks', () {
    test('выдаёт выбор после каждого изменения', () async {
      final watch = WatchActiveDecks(repository);
      final expectation = expectLater(
        watch(),
        emitsInOrder([
          isEmpty,
          emitsThrough({Small.skellige: 'deck-skellige'}),
        ]),
      );
      await pumpEventQueue();
      final deck = smallSkelligeDeck();
      await repository.save(deck);
      await repository.setActive(deck.id);
      await expectation;
    });
  });
}
