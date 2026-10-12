import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;

import '../../../support/factories.dart';
import '../../../support/fakes.dart';

void main() {
  late InMemoryDeckRepository decks;
  late MatchSetupCubit cubit;

  setUp(() {
    decks = InMemoryDeckRepository([testDeck(id: 'a'), testDeck(id: 'b')]);
    cubit = MatchSetupCubit(WatchDecks(decks));
    addTearDown(cubit.close);
  });

  Future<MatchSetupReady> ready() async => switch (cubit.state) {
    final MatchSetupReady state => state,
    _ => await cubit.stream.firstWhere((state) => state is MatchSetupReady) as MatchSetupReady,
  };

  test('колоды без выбора; по умолчанию против бота', () async {
    final state = await ready();
    expect(state.decks.map((deck) => deck.id), unorderedEquals(['a', 'b']));
    expect(state.mode, LocalMatchMode.vsBot);
    expect(state.request, isNull);
  });

  test('выбраны обе колоды и режим: готовый запрос', () async {
    await ready();
    cubit
      ..selectDeck(Seat.one, 'a')
      ..selectDeck(Seat.two, 'b')
      ..selectMode(LocalMatchMode.hotSeat);
    final state = cubit.state as MatchSetupReady;
    expect(state.deck(Seat.one), 'a');
    expect(
      state.request,
      isA<LocalMatchRequest>()
          .having((request) => request.mode, 'mode', LocalMatchMode.hotSeat)
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

  test('пока колоды читаются, состояние загрузки; режим, выбранный до них, сохраняется', () async {
    final lateDecks = _LateDecks();
    addTearDown(lateDecks.close);
    final waiting = MatchSetupCubit(WatchDecks(lateDecks));
    addTearDown(waiting.close);
    waiting.selectMode(LocalMatchMode.hotSeat);
    expect(waiting.state, isA<MatchSetupLoading>());

    lateDecks.decks.add([testDeck()]);
    final state = await waiting.stream.first as MatchSetupReady;
    expect(state.mode, LocalMatchMode.hotSeat);
    expect(state.decks, [testDeck()]);
  });

  test('ошибка чтения колод', () async {
    final failure = Exception('база недоступна');
    final failing = MatchSetupCubit(WatchDecks(InMemoryDeckRepository()..watchError = failure));
    addTearDown(failing.close);
    expect(await failing.stream.first, isA<MatchSetupFailed>().having((state) => state.error, 'error', failure));
  });
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
