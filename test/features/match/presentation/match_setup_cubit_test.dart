import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/application/get_active_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/application/set_active_deck.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules_source.dart';
import 'package:gwent/src/features/match/application/choose_opponent_deck.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat, TooFewUnitCards;

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/fakes.dart';

void main() {
  late InMemoryDeckRepository repository;
  late DeckRulesSource rules;

  setUp(() {
    repository = InMemoryDeckRepository();
    rules = FakeDeckRulesSource();
  });

  /// Держатель над настоящими сценариями и фальшивым хранилищем.
  MatchSetupCubit build(LocalMatchMode mode, {DeckRulesSource? source}) {
    final used = source ?? rules;
    final lock = DeckSelectionLock();
    final starter = CreateStarterDeck(repository, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator());
    final getActive = GetActiveDeck(repository, used, starter, lock);
    final cubit = MatchSetupCubit(
      watchDecks: WatchDecks(repository),
      loadDeckRules: LoadDeckRules(used),
      getActiveDeck: getActive,
      setActiveDeck: SetActiveDeck(repository, used, lock),
      chooseOpponentDeck: ChooseOpponentDeck(used, getActive),
      mode: mode,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<MatchSetupReady> ready(MatchSetupCubit cubit) async => switch (cubit.state) {
    final MatchSetupReady state => state,
    _ => await cubit.stream.firstWhere((state) => state is MatchSetupReady) as MatchSetupReady,
  };

  MatchSetupReady now(MatchSetupCubit cubit) => cubit.state as MatchSetupReady;

  /// Доходит до шага колод: фракция [factionIndex], лидер [leader] (без него — первый).
  Future<void> toDeckStep(MatchSetupCubit cubit, {int factionIndex = 0, String? leader}) async {
    await ready(cubit);
    cubit
      ..showFaction(factionIndex)
      ..confirmFaction();
    if (leader != null) cubit.selectLeader(leader);
    await cubit.confirmLeader();
  }

  Deck monstersDeck({String id = 'deck-monsters'}) => Deck(
    id: id,
    name: 'Чудовища',
    factionId: Small.monsters,
    leaderId: Small.eredin,
    cards: const {Small.ghoul: 3, Small.geralt: 1, Small.vesemir: 2, Small.frost: 1},
    updatedAt: DateTime.utc(2026, 10, 12),
  );

  group('фракция и лидер', () {
    test('пока правила читаются, загрузка; потом первая фракция пакета на первом месте', () async {
      final cubit = build(LocalMatchMode.vsBot);
      expect(cubit.state, isA<MatchSetupLoading>());

      final state = await ready(cubit);
      expect(state.step, SetupStep.faction);
      expect(state.seat, Seat.one);
      expect(state.faction.id, Small.skellige);
      expect(state.rules.factionInfos.map((faction) => faction.id), [Small.skellige, Small.monsters]);
      expect(state.canStepBack, isFalse, reason: 'с первого шага первого места назад только из выбора в меню');
      expect(state.isHotSeat, isFalse);
      expect(state.isLastSeat, isTrue);
    });

    test('листание меняет фракцию и сбрасывает лидера; за пределы списка и мимо шага не листает', () async {
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit);

      cubit
        ..showFaction(5)
        ..showFaction(-1);
      expect(now(cubit).factionIndex, 0);

      cubit.showFaction(1);
      expect(now(cubit).faction.id, Small.monsters);

      cubit.confirmFaction();
      cubit.showFaction(0);
      expect(now(cubit).factionIndex, 1, reason: 'на шаге лидера фракцию не листают');
    });

    test('подтверждение фракции открывает лидеров; выбран первый лидер фракции', () async {
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit);

      cubit.confirmFaction();

      final state = now(cubit);
      expect(state.step, SetupStep.leader);
      expect(state.leaderId, Small.crach);
      expect(state.leader?.id, Small.crach);
      expect(state.canStepBack, isTrue);
    });

    test('лидера чужой фракции выбрать нельзя, своего можно', () async {
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit);
      cubit.confirmFaction();

      cubit.selectLeader(Small.eredin);
      expect(now(cubit).leaderId, Small.crach);

      cubit.selectLeader(Small.bran);
      expect(now(cubit).leaderId, Small.bran);
    });

    test('вернувшись на фракцию и обратно, игрок находит прежнего лидера', () async {
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit);
      cubit
        ..confirmFaction()
        ..selectLeader(Small.bran);

      expect(cubit.back(), isTrue);
      expect(now(cubit).step, SetupStep.faction);
      cubit.confirmFaction();

      expect(now(cubit).leaderId, Small.bran);
    });
  });

  group('колода', () {
    test('у фракции без колод создаётся стартовая и выбирается заранее', () async {
      final cubit = build(LocalMatchMode.vsBot);
      await toDeckStep(cubit);

      final state = now(cubit);
      expect(state.step, SetupStep.deck);
      expect(state.decks, hasLength(1));
      expect(state.deckId, state.decks.single.deck.id);
      expect(state.decks.single.ready, isTrue);
      expect(state.busy, isFalse);
    });

    test('выбрана активная колода фракции, а в списке только колоды этой фракции', () async {
      await repository.save(smallSkelligeDeck(id: 'old', updatedAt: DateTime.utc(2026, 10, 10)));
      await repository.save(smallSkelligeDeck(id: 'active', updatedAt: DateTime.utc(2026, 10, 11)), activate: true);
      await repository.save(monstersDeck());
      final cubit = build(LocalMatchMode.vsBot);

      await toDeckStep(cubit);

      final state = now(cubit);
      expect(state.decks.map((choice) => choice.deck.id), ['active', 'old']);
      expect(state.deckId, 'active');
    });

    test('лидер партии заменяет лидера колоды: колода годится с любым лидером своей фракции', () async {
      await repository.save(smallSkelligeDeck());
      final cubit = build(LocalMatchMode.vsBot);

      await toDeckStep(cubit, leader: Small.bran);

      final choice = now(cubit).decks.single;
      expect(choice.deck.leaderId, Small.crach, reason: 'сохранённая колода не меняется');
      expect(choice.ready, isTrue);
      expect(now(cubit).leaderId, Small.bran);
    });

    test('негодная колода: причины видны, выбрать можно, подтвердить нельзя', () async {
      await repository.save(smallSkelligeDeck(id: 'bad', cards: const {Small.warrior: 3}));
      await repository.save(smallSkelligeDeck(id: 'good'));
      final cubit = build(LocalMatchMode.vsBot);
      await toDeckStep(cubit);
      expect(now(cubit).deckId, 'good', reason: 'заранее выбирается годная колода, хоть она и старше');

      cubit.selectDeck('bad');
      final state = now(cubit);
      expect(state.selectedDeck?.ready, isFalse);
      expect(state.selectedDeck?.issues, [const DeckRuleViolation(TooFewUnitCards(count: 3, min: 5))]);

      await cubit.confirmDeck();
      expect(cubit.state, isA<MatchSetupReady>(), reason: 'партия с негодной колодой не начинается');
    });

    test('колоду другой фракции выбрать нельзя', () async {
      await repository.save(monstersDeck());
      final cubit = build(LocalMatchMode.vsBot);
      await toDeckStep(cubit);
      final before = now(cubit).deckId;

      cubit.selectDeck('deck-monsters');

      expect(now(cubit).deckId, before);
    });

    test('выбранную колоду удалили: выбор падает на оставшуюся годную', () async {
      await repository.save(smallSkelligeDeck(id: 'a', updatedAt: DateTime.utc(2026, 10, 12)));
      await repository.save(smallSkelligeDeck(id: 'b', updatedAt: DateTime.utc(2026, 10, 11)));
      final cubit = build(LocalMatchMode.vsBot);
      await toDeckStep(cubit);
      cubit.selectDeck('a');

      final updated = cubit.stream.firstWhere((state) => state is MatchSetupReady && state.decks.length == 1);
      await repository.delete('a');

      expect((await updated as MatchSetupReady).deckId, 'b');
    });

    test('колоду отредактировали в конструкторе: список обновляется, не вернув игрока на шаг назад', () async {
      await repository.save(smallSkelligeDeck(id: 'a', cards: const {Small.warrior: 3}));
      await repository.save(smallSkelligeDeck(id: 'b'));
      final cubit = build(LocalMatchMode.vsBot);
      await toDeckStep(cubit);
      cubit.selectDeck('a');
      expect(now(cubit).selectedDeck?.ready, isFalse);

      final fixed = cubit.stream.firstWhere((state) => state is MatchSetupReady && state.selectedDeck?.ready == true);
      await repository.save(smallSkelligeDeck(id: 'a', updatedAt: DateTime.utc(2026, 10, 13)));

      final state = await fixed as MatchSetupReady;
      expect(state.step, SetupStep.deck);
      expect(state.deckId, 'a');
    });
  });

  group('партия против бота', () {
    test('подтверждённая колода готовит запрос: лидер игрока и колода бота следующей фракции', () async {
      await repository.save(smallSkelligeDeck(id: 'mine'));
      final cubit = build(LocalMatchMode.vsBot);
      await toDeckStep(cubit, leader: Small.bran);

      final done = cubit.stream.firstWhere((state) => state is MatchSetupDone);
      await cubit.confirmDeck();

      final request = (await done as MatchSetupDone).request;
      expect(request.mode, LocalMatchMode.vsBot);
      expect(request.deckOne, 'mine');
      expect(request.leaderOne, Small.bran);
      expect(request.leaderTwo, isNull, reason: 'бот играет лидером своей колоды');
      final bot = (await repository.findById(request.deckTwo))!;
      expect(
        bot.factionId,
        Small.monsters,
        reason: 'после последней фракции в пакете идёт первая, после первой вторая',
      );
    });

    test('после последней фракции бот играет первой', () async {
      await repository.save(monstersDeck());
      final cubit = build(LocalMatchMode.vsBot);
      await toDeckStep(cubit, factionIndex: 1);

      final done = cubit.stream.firstWhere((state) => state is MatchSetupDone);
      await cubit.confirmDeck();

      final request = (await done as MatchSetupDone).request;
      expect((await repository.findById(request.deckTwo))!.factionId, Small.skellige);
    });

    test('выбранная колода становится активной колодой фракции', () async {
      await repository.save(smallSkelligeDeck(id: 'first', updatedAt: DateTime.utc(2026, 10, 12)), activate: true);
      await repository.save(smallSkelligeDeck(id: 'second'));
      final cubit = build(LocalMatchMode.vsBot);
      await toDeckStep(cubit);
      cubit.selectDeck('second');

      await cubit.confirmDeck();

      expect(await repository.findActiveDeckId(Small.skellige), 'second');
    });

    test('после окончания выбора состояние больше не меняется', () async {
      await repository.save(smallSkelligeDeck());
      final cubit = build(LocalMatchMode.vsBot);
      await toDeckStep(cubit);
      await cubit.confirmDeck();
      expect(cubit.state, isA<MatchSetupDone>());

      await repository.save(smallSkelligeDeck(id: 'other'));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<MatchSetupDone>());
    });

    test('двойное нажатие «Играть» не создаёт второй запрос', () async {
      await repository.save(smallSkelligeDeck());
      final cubit = build(LocalMatchMode.vsBot);
      await toDeckStep(cubit);
      final emitted = <MatchSetupState>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      await Future.wait([cubit.confirmDeck(), cubit.confirmDeck()]);
      await pumpEventQueue();

      expect(emitted.whereType<MatchSetupDone>(), hasLength(1));
    });
  });

  group('партия вдвоём на одном телефоне', () {
    test('места выбирают по очереди, запрос несёт колоды и лидеров обоих', () async {
      await repository.save(smallSkelligeDeck(id: 'one'));
      await repository.save(monstersDeck(id: 'two'));
      final cubit = build(LocalMatchMode.hotSeat);
      await toDeckStep(cubit, leader: Small.bran);
      expect(now(cubit).isHotSeat, isTrue);
      expect(now(cubit).isLastSeat, isFalse);

      await cubit.confirmDeck();
      final state = now(cubit);
      expect(state.seat, Seat.two);
      expect(state.step, SetupStep.faction);
      expect(state.leaderId, isNull);
      expect(state.isLastSeat, isTrue);
      expect(state.canStepBack, isTrue, reason: 'со второго места можно вернуться к колоде первого');

      cubit
        ..showFaction(1)
        ..confirmFaction();
      await cubit.confirmLeader();
      expect(now(cubit).deckId, 'two');
      final done = cubit.stream.firstWhere((state) => state is MatchSetupDone);
      await cubit.confirmDeck();

      final request = (await done as MatchSetupDone).request;
      expect(
        (request.mode, request.deckOne, request.deckTwo, request.leaderOne, request.leaderTwo),
        (LocalMatchMode.hotSeat, 'one', 'two', Small.bran, Small.eredin),
      );
    });

    test('«назад» со второго места возвращает к колоде первого, выбор которого сохранён', () async {
      await repository.save(smallSkelligeDeck(id: 'one'));
      final cubit = build(LocalMatchMode.hotSeat);
      await toDeckStep(cubit, leader: Small.bran);
      await cubit.confirmDeck();

      expect(cubit.back(), isTrue);

      final state = now(cubit);
      expect(state.seat, Seat.one);
      expect(state.step, SetupStep.deck);
      expect(state.faction.id, Small.skellige);
      expect(state.leaderId, Small.bran);
      expect(state.deckId, 'one');
    });

    test('оба места могут играть одной фракцией и одной колодой', () async {
      await repository.save(smallSkelligeDeck(id: 'only'));
      final cubit = build(LocalMatchMode.hotSeat);
      await toDeckStep(cubit);
      await cubit.confirmDeck();
      await toDeckStep(cubit);
      final done = cubit.stream.firstWhere((state) => state is MatchSetupDone);
      await cubit.confirmDeck();

      final request = (await done as MatchSetupDone).request;
      expect((request.deckOne, request.deckTwo), ('only', 'only'));
    });
  });

  group('«назад»', () {
    test('шаги возвращаются по одному; с первого шага первого места назад некуда', () async {
      final cubit = build(LocalMatchMode.vsBot);
      await toDeckStep(cubit);

      expect(cubit.back(), isTrue);
      expect(now(cubit).step, SetupStep.leader);
      expect(cubit.back(), isTrue);
      expect(now(cubit).step, SetupStep.faction);
      expect(cubit.back(), isFalse);
      expect(now(cubit).step, SetupStep.faction);
    });

    test('пока правила читаются, назад некуда', () {
      expect(build(LocalMatchMode.vsBot).back(), isFalse);
    });
  });

  group('ошибки', () {
    test('пакет не прошёл проверку: ошибка вместо выбора', () async {
      final cubit = build(LocalMatchMode.vsBot, source: _FailingRules());

      final state = await cubit.stream.firstWhere((state) => state is MatchSetupFailed);

      expect((state as MatchSetupFailed).error, isA<DeckRulesUnavailableException>());
    });

    test('сбой чтения колод: ошибка, и позднее обновление её не затирает', () async {
      repository.watchError = Exception('нет доступа');
      final cubit = build(LocalMatchMode.vsBot);

      final state = await cubit.stream.firstWhere((state) => state is MatchSetupFailed);

      expect((state as MatchSetupFailed).error, isA<Exception>());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cubit.state, isA<MatchSetupFailed>());
    });

    test('сбой подготовки колоды: ошибка вместо вечной загрузки', () async {
      final cubit = build(LocalMatchMode.vsBot, source: _RulesOnce(smallDeckRules));
      await ready(cubit);
      cubit.confirmFaction();

      await cubit.confirmLeader();

      expect(cubit.state, isA<MatchSetupFailed>());
    });

    test('закрытый держатель не падает на позднем ответе', () async {
      await repository.save(smallSkelligeDeck());
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit);
      cubit.confirmFaction();

      final pending = cubit.confirmLeader();
      await cubit.close();

      await expectLater(pending, completes);
    });
  });
}

/// Источник, который не отдаёт правила: пакет не прошёл проверку.
final class _FailingRules implements DeckRulesSource {
  @override
  Future<DeckRules> load() async => throw DeckRulesUnavailableException(const []);
}

/// Источник, который отдаёт правила один раз, а потом ломается: как если бы пакет пропал, пока игрок выбирал.
final class _RulesOnce implements DeckRulesSource {
  _RulesOnce(this._rules);

  final DeckRules _rules;
  bool _served = false;

  @override
  Future<DeckRules> load() async {
    if (_served) throw DeckRulesUnavailableException(const []);
    _served = true;
    return _rules;
  }
}
