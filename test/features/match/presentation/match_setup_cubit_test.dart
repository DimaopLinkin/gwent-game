import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/application/ensure_starter_decks.dart';
import 'package:gwent/src/features/deck_builder/application/get_active_deck.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';
import 'package:gwent/src/features/match/application/choose_default_decks.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/factories.dart';
import '../../../support/fakes.dart';

void main() {
  late InMemoryDeckRepository decks;
  late MatchSetupCubit cubit;

  setUp(() {
    decks = InMemoryDeckRepository([testDeck(id: 'a'), testDeck(id: 'b')]);
    cubit = MatchSetupCubit(WatchDecks(decks), mode: LocalMatchMode.vsBot);
    addTearDown(cubit.close);
  });

  Future<MatchSetupReady> ready() async => switch (cubit.state) {
    final MatchSetupReady state => state,
    _ => await cubit.stream.firstWhere((state) => state is MatchSetupReady) as MatchSetupReady,
  };

  test('колоды без выбора; режим берётся из меню', () async {
    final state = await ready();
    expect(state.decks.map((deck) => deck.id), unorderedEquals(['a', 'b']));
    expect(state.mode, LocalMatchMode.vsBot);
    expect(state.request, isNull);
  });

  test('выбраны обе колоды и режим: готовый запрос', () async {
    await ready();
    cubit
      ..selectDeck(Seat.one, 'a')
      ..selectDeck(Seat.two, 'b');
    final state = cubit.state as MatchSetupReady;
    expect(state.deck(Seat.one), 'a');
    expect(
      state.request,
      isA<LocalMatchRequest>()
          .having((request) => request.mode, 'mode', LocalMatchMode.vsBot)
          .having((request) => request.deckOne, 'deckOne', 'a')
          .having((request) => request.deckTwo, 'deckTwo', 'b'),
    );
  });

  test('неизвестную колоду выбрать нельзя, удалённая колода снимается с выбора', () async {
    await ready();
    cubit
      ..selectDeck(Seat.one, 'missing')
      ..selectDeck(Seat.two, 'b');
    expect((cubit.state as MatchSetupReady).deckOne, isNull);

    final updated = cubit.stream.firstWhere((state) => state is MatchSetupReady && state.decks.length == 1);
    await decks.delete('b');
    expect((await updated as MatchSetupReady).deckTwo, isNull);
  });

  test('пока колоды читаются, состояние загрузки; режим из меню доходит до готового выбора', () async {
    final lateDecks = _LateDecks();
    addTearDown(lateDecks.close);
    final waiting = MatchSetupCubit(WatchDecks(lateDecks), mode: LocalMatchMode.hotSeat);
    addTearDown(waiting.close);
    expect(waiting.state, isA<MatchSetupLoading>());

    lateDecks.decks.add([testDeck()]);
    final state = await waiting.stream.first as MatchSetupReady;
    expect(state.mode, LocalMatchMode.hotSeat);
    expect(state.decks, [testDeck()]);
  });

  group('стартовые колоды и предвыбор', () {
    EnsureStarterDecks ensure(DeckRepository repository, DeckRulesSource rules) => EnsureStarterDecks(
      repository,
      rules,
      CreateStarterDeck(repository, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator()),
      DeckSelectionLock(),
    );

    test('на пустом хранилище каждая фракция получает стартовую колоду', () async {
      final empty = InMemoryDeckRepository();
      final rules = FakeDeckRulesSource();
      final started = MatchSetupCubit(
        WatchDecks(empty),
        mode: LocalMatchMode.vsBot,
        ensureStarterDecks: ensure(empty, rules),
      );
      addTearDown(started.close);
      final state = await started.stream.firstWhere(
        (state) => state is MatchSetupReady && state.decks.length == rules.rules.deckFactions.length,
      );
      expect((state as MatchSetupReady).decks, isNotEmpty);
      expect(state.request, isNull, reason: 'без preselect выбор остаётся за игроком');
    });

    test('предвыбор ставит первую колоду на оба места, ручной выбор не затирается', () async {
      final repository = InMemoryDeckRepository([testDeck(id: 'a'), testDeck(id: 'b')]);
      final preselected = MatchSetupCubit(WatchDecks(repository), mode: LocalMatchMode.vsBot, preselect: true);
      addTearDown(preselected.close);
      final state = await preselected.stream.firstWhere((state) => state is MatchSetupReady) as MatchSetupReady;
      expect(state.request, isNotNull);
      expect(state.deckOne, state.decks.first.id);
      expect(state.deckTwo, state.decks.first.id);

      final other = state.decks.last.id;
      preselected.selectDeck(Seat.two, other);
      await repository.save(testDeck(id: 'c'));
      final updated = await preselected.stream.firstWhere(
        (state) => state is MatchSetupReady && state.decks.length == 3,
      );
      expect((updated as MatchSetupReady).deckTwo, other);
    });

    ChooseDefaultDecks chooser(DeckRepository repository, DeckRulesSource rules) => ChooseDefaultDecks(
      rules,
      GetActiveDeck(
        repository,
        rules,
        CreateStarterDeck(repository, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator()),
        DeckSelectionLock(),
      ),
    );

    test('колоды по умолчанию: на места встают активные колоды двух первых фракций', () async {
      final repository = InMemoryDeckRepository();
      final rules = FakeDeckRulesSource();
      final cubit = MatchSetupCubit(
        WatchDecks(repository),
        mode: LocalMatchMode.hotSeat,
        ensureStarterDecks: ensure(repository, rules),
        chooseDefaultDecks: chooser(repository, rules),
      );
      addTearDown(cubit.close);
      final state =
          await cubit.stream.firstWhere((state) => state is MatchSetupReady && state.request != null)
              as MatchSetupReady;
      final one = state.decks.firstWhere((deck) => deck.id == state.deckOne);
      final two = state.decks.firstWhere((deck) => deck.id == state.deckTwo);
      expect(one.factionId, rules.rules.deckFactions[0].id);
      expect(two.factionId, rules.rules.deckFactions[1].id);
      expect(state.request!.mode, LocalMatchMode.hotSeat);
    });

    test('колода по умолчанию не затирает выбор игрока', () async {
      final repository = InMemoryDeckRepository([testDeck(id: 'a'), testDeck(id: 'b')]);
      final rules = FakeDeckRulesSource();
      final cubit = MatchSetupCubit(
        WatchDecks(repository),
        mode: LocalMatchMode.vsBot,
        ensureStarterDecks: ensure(repository, rules),
        chooseDefaultDecks: chooser(repository, rules),
      );
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((state) => state is MatchSetupReady);
      cubit.selectDeck(Seat.one, 'b');
      await pumpEventQueue();
      expect((cubit.state as MatchSetupReady).deckOne, 'b');
    });

    test('без колод по умолчанию и без предвыбора выбор остаётся за игроком', () async {
      final repository = InMemoryDeckRepository([testDeck(id: 'a')]);
      final rules = FakeDeckRulesSource();
      final cubit = MatchSetupCubit(
        WatchDecks(repository),
        mode: LocalMatchMode.vsBot,
        ensureStarterDecks: ensure(repository, rules),
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      final state = cubit.state as MatchSetupReady;
      expect(state.deckOne, isNull);
      expect(state.request, isNull);
    });

    test('без колод предвыбирать нечего', () async {
      final empty = InMemoryDeckRepository();
      final preselected = MatchSetupCubit(WatchDecks(empty), mode: LocalMatchMode.vsBot, preselect: true);
      addTearDown(preselected.close);
      final state = await preselected.stream.firstWhere((state) => state is MatchSetupReady) as MatchSetupReady;
      expect(state.request, isNull);
    });

    test('стартовые колоды создать не удалось: состояние ошибки', () async {
      final failure = StateError('нет пакета');
      final failing = _FailingRules(failure);
      final repository = InMemoryDeckRepository();
      final cubit = MatchSetupCubit(
        WatchDecks(repository),
        mode: LocalMatchMode.vsBot,
        ensureStarterDecks: ensure(repository, failing),
      );
      addTearDown(cubit.close);
      final state = await cubit.stream.firstWhere((state) => state is MatchSetupFailed);
      expect((state as MatchSetupFailed).error, failure);
    });
  });

  test('ошибка чтения колод', () async {
    final failure = Exception('база недоступна');
    final failing = MatchSetupCubit(
      WatchDecks(InMemoryDeckRepository()..watchError = failure),
      mode: LocalMatchMode.vsBot,
    );
    addTearDown(failing.close);
    expect(await failing.stream.first, isA<MatchSetupFailed>().having((state) => state.error, 'error', failure));
  });
}

/// Источник правил, который не отдаёт их.
final class _FailingRules implements DeckRulesSource {
  _FailingRules(this.error);

  final Object error;

  @override
  Future<DeckRules> load() => Future.error(error);
}

/// Хранилище, которое отдаёт список колод, только когда тест его добавит.
final class _LateDecks implements DeckRepository {
  final StreamController<List<Deck>> decks = StreamController();

  Future<void> close() => decks.close();

  @override
  Stream<List<Deck>> watchAll() => decks.stream;

  @override
  Future<Deck?> findById(String id) async => null;

  @override
  Future<List<Deck>> findByFaction(String factionId) async => const [];

  @override
  Future<void> save(Deck deck, {bool activate = false}) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Stream<Map<String, String>> watchActiveDeckIds() => const Stream.empty();

  @override
  Future<String?> findActiveDeckId(String factionId) async => null;

  @override
  Future<void> setActive(String deckId) async {}
}
