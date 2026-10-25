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
import 'package:gwent/src/features/settings/application/load_bot_difficulty.dart';
import 'package:gwent/src/features/settings/application/save_bot_difficulty.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;
import 'package:gwent_engine/gwent_engine.dart' show Seat, TooFewUnitCards;

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/fakes.dart';

void main() {
  late InMemoryDeckRepository repository;
  late DeckRulesSource rules;
  late InMemorySettingsRepository settings;

  setUp(() {
    settings = InMemorySettingsRepository();
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
      chooseOpponentDeck: ChooseOpponentDeck(used, FixedSeedGenerator(1)),
      loadBotDifficulty: LoadBotDifficulty(settings),
      saveBotDifficulty: SaveBotDifficulty(settings),
      mode: mode,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  /// Состояние выбора, когда оно готово. Против бота сначала проходит шаг сложности (с уровнем из настроек),
  /// если [pastDifficulty] не отключён: остальные тесты начинаются с выбора фракции.
  Future<MatchSetupReady> ready(MatchSetupCubit cubit, {bool pastDifficulty = true}) async {
    final state = switch (cubit.state) {
      final MatchSetupReady state => state,
      _ => await cubit.stream.firstWhere((state) => state is MatchSetupReady) as MatchSetupReady,
    };
    if (pastDifficulty && state.step == SetupStep.difficulty) {
      await cubit.confirmDifficulty();
      return cubit.state as MatchSetupReady;
    }
    return state;
  }

  MatchSetupReady now(MatchSetupCubit cubit) => cubit.state as MatchSetupReady;

  /// Доходит до шага колод фракции с номером [factionIndex].
  Future<void> toDeckStep(MatchSetupCubit cubit, {int factionIndex = 0}) async {
    await ready(cubit);
    cubit.showFaction(factionIndex);
    await cubit.confirmFaction();
  }

  Deck monstersDeck({String id = 'deck-monsters'}) => Deck(
    id: id,
    name: 'Чудовища',
    factionId: Small.monsters,
    leaderId: Small.eredin,
    cards: const {Small.ghoul: 3, Small.geralt: 1, Small.vesemir: 2, Small.frost: 1},
    updatedAt: DateTime.utc(2026, 10, 12),
  );

  group('фракция', () {
    test('пока правила читаются, загрузка; потом первая фракция пакета на первом месте', () async {
      final cubit = build(LocalMatchMode.vsBot);
      expect(cubit.state, isA<MatchSetupLoading>());

      final state = await ready(cubit);
      expect(state.step, SetupStep.faction);
      expect(state.seat, Seat.one);
      expect(state.faction.id, Small.skellige);
      expect(state.rules.factionInfos.map((faction) => faction.id), [Small.skellige, Small.monsters]);
      expect(state.canStepBack, isTrue, reason: 'против бота с выбора фракции назад ведёт к сложности');
      expect(state.isHotSeat, isFalse);
      expect(state.isLastSeat, isTrue);
    });

    test('листание меняет фракцию; за пределы списка и мимо шага не листает', () async {
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit);

      cubit
        ..showFaction(5)
        ..showFaction(-1);
      expect(now(cubit).factionIndex, 0);

      cubit.showFaction(1);
      expect(now(cubit).faction.id, Small.monsters);

      await cubit.confirmFaction();
      cubit.showFaction(0);
      expect(now(cubit).factionIndex, 1, reason: 'на шаге колоды фракцию не листают');
    });

    test('подтверждение фракции сразу открывает её колоды, без выбора лидера', () async {
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit);

      await cubit.confirmFaction();

      final state = now(cubit);
      expect(state.step, SetupStep.deck);
      expect(state.canStepBack, isTrue);
    });
  });

  group('колода', () {
    test('двойное подтверждение фракции открывает колоды один раз', () async {
      await repository.save(smallSkelligeDeck());
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit);
      await Future.wait([cubit.confirmFaction(), cubit.confirmFaction()]);
      await pumpEventQueue();

      expect(now(cubit).step, SetupStep.deck);
      expect(now(cubit).busy, isFalse);
    });

    test('пока колода сохраняется, «назад» ничего не меняет, но из выбора не выходит', () async {
      await repository.save(smallSkelligeDeck());
      final cubit = build(LocalMatchMode.hotSeat);
      await toDeckStep(cubit);

      final pending = cubit.confirmDeck();
      expect(cubit.back(), isTrue);
      await pending;

      expect(now(cubit).seat, Seat.two, reason: 'выбор первого места не откатился');
    });

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

    test('лидер берётся из колоды: у каждой колоды свой, и все годятся в партию', () async {
      await repository.save(smallSkelligeDeck(id: 'crach', updatedAt: DateTime.utc(2026, 10, 11)));
      await repository.save(
        smallSkelligeDeck(id: 'bran', updatedAt: DateTime.utc(2026, 10, 10)).copyWith(leaderId: Small.bran),
      );
      final cubit = build(LocalMatchMode.vsBot);

      await toDeckStep(cubit);

      final choices = now(cubit).decks;
      expect(
        {for (final choice in choices) choice.deck.id: choice.deck.leaderId},
        {
          'crach': Small.crach,
          'bran': Small.bran,
        },
      );
      expect(choices.every((choice) => choice.ready), isTrue);
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

  group('сложность бота', () {
    test('против бота выбор начинается со сложности, выбран нормальный уровень', () async {
      final cubit = build(LocalMatchMode.vsBot);
      final state = await ready(cubit, pastDifficulty: false);

      expect(state.step, SetupStep.difficulty);
      expect(state.difficulty, BotDifficulty.normal);
      expect(state.canStepBack, isFalse, reason: 'первый шаг: назад только в меню');
      expect(state.stepTotal, 3);
      expect(state.stepNumber(SetupStep.faction), 2);
      expect(state.stepNumber(SetupStep.deck), 3);
    });

    test('в hot-seat шага сложности нет', () async {
      final state = await ready(build(LocalMatchMode.hotSeat), pastDifficulty: false);

      expect(state.step, SetupStep.faction);
      expect(state.stepTotal, 2);
      expect(state.stepNumber(SetupStep.deck), 2);
    });

    test('уровень запоминается при подтверждении и выбран заранее в следующий раз', () async {
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit, pastDifficulty: false);
      cubit.selectDifficulty(BotDifficulty.deathMatch);
      expect(settings.saved.botDifficulty, BotDifficulty.normal, reason: 'пока не подтверждён, не сохраняется');

      await cubit.confirmDifficulty();

      expect(now(cubit).step, SetupStep.faction);
      expect(settings.saved.botDifficulty, BotDifficulty.deathMatch);
      final next = build(LocalMatchMode.vsBot);
      expect((await ready(next, pastDifficulty: false)).difficulty, BotDifficulty.deathMatch);
    });

    test('назад с выбора фракции возвращает к сложности', () async {
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit);

      expect(cubit.back(), isTrue);
      expect(now(cubit).step, SetupStep.difficulty);
      expect(cubit.back(), isFalse);
    });

    test('пока уровень сохраняется, другой выбрать нельзя', () async {
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit, pastDifficulty: false);
      cubit.selectDifficulty(BotDifficulty.hard);

      final confirming = cubit.confirmDifficulty();
      cubit.selectDifficulty(BotDifficulty.easy);
      await confirming;

      expect(now(cubit).difficulty, BotDifficulty.hard);
      expect(settings.saved.botDifficulty, BotDifficulty.hard);
    });

    test('сбой хранилища настроек не мешает выбору: уровень «Нормальный», выбор идёт дальше', () async {
      settings = _BrokenSettingsRepository();
      final cubit = build(LocalMatchMode.vsBot);
      final state = await ready(cubit, pastDifficulty: false);
      expect(state.difficulty, BotDifficulty.normal);

      cubit.selectDifficulty(BotDifficulty.hard);
      await cubit.confirmDifficulty();

      expect(now(cubit).step, SetupStep.faction);
      expect(now(cubit).difficulty, BotDifficulty.hard);
    });

    test('уровень можно выбирать только на шаге сложности', () async {
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit);

      cubit.selectDifficulty(BotDifficulty.easy);

      expect(now(cubit).difficulty, BotDifficulty.normal);
    });
  });

  group('партия против бота', () {
    test('подтверждённая колода готовит запрос: колода игрока, уровень и собранная колода бота', () async {
      await repository.save(smallSkelligeDeck(id: 'mine'));
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit, pastDifficulty: false);
      cubit.selectDifficulty(BotDifficulty.hard);
      await cubit.confirmDifficulty();
      await toDeckStep(cubit);

      final done = cubit.stream.firstWhere((state) => state is MatchSetupDone);
      await cubit.confirmDeck();

      final request = (await done as MatchSetupDone).request;
      expect(request.mode, LocalMatchMode.vsBot);
      expect(request.deckOne, 'mine');
      expect(request.difficulty, BotDifficulty.hard);
      final bot = request.opponentDeck!;
      expect(request.deckTwo, bot.id);
      expect(await repository.findById(bot.id), isNull, reason: 'колода бота в хранилище не попадает');
      expect(smallDeckRules.check(bot), isEmpty);
    });

    test('фракция бота случайна и может совпасть с фракцией игрока', () async {
      await repository.save(monstersDeck());
      final factions = <String>{};
      for (var seed = 0; seed < 20; seed++) {
        final cubit = MatchSetupCubit(
          watchDecks: WatchDecks(repository),
          loadDeckRules: LoadDeckRules(rules),
          getActiveDeck: GetActiveDeck(
            repository,
            rules,
            CreateStarterDeck(repository, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator()),
            DeckSelectionLock(),
          ),
          setActiveDeck: SetActiveDeck(repository, rules, DeckSelectionLock()),
          chooseOpponentDeck: ChooseOpponentDeck(rules, FixedSeedGenerator(seed)),
          loadBotDifficulty: LoadBotDifficulty(settings),
          saveBotDifficulty: SaveBotDifficulty(settings),
          mode: LocalMatchMode.vsBot,
        );
        addTearDown(cubit.close);
        await toDeckStep(cubit, factionIndex: 1);
        final done = cubit.stream.firstWhere((state) => state is MatchSetupDone);
        await cubit.confirmDeck();
        factions.add(((await done as MatchSetupDone).request.opponentDeck!).factionId);
      }

      expect(factions, {Small.skellige, Small.monsters}, reason: 'против Чудовищ встречается и зеркало');
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
    test('места выбирают по очереди, запрос несёт колоды обоих', () async {
      await repository.save(smallSkelligeDeck(id: 'one'));
      await repository.save(monstersDeck(id: 'two'));
      final cubit = build(LocalMatchMode.hotSeat);
      await toDeckStep(cubit);
      expect(now(cubit).isHotSeat, isTrue);
      expect(now(cubit).isLastSeat, isFalse);

      await cubit.confirmDeck();
      final state = now(cubit);
      expect(state.seat, Seat.two);
      expect(state.step, SetupStep.faction);
      expect(state.isLastSeat, isTrue);
      expect(state.canStepBack, isTrue, reason: 'со второго места можно вернуться к колоде первого');

      cubit.showFaction(1);
      await cubit.confirmFaction();
      expect(now(cubit).deckId, 'two');
      final done = cubit.stream.firstWhere((state) => state is MatchSetupDone);
      await cubit.confirmDeck();

      final request = (await done as MatchSetupDone).request;
      expect((request.mode, request.deckOne, request.deckTwo), (LocalMatchMode.hotSeat, 'one', 'two'));
    });

    test('«назад» со второго места возвращает к колоде первого, выбор которого сохранён', () async {
      await repository.save(smallSkelligeDeck(id: 'one'));
      final cubit = build(LocalMatchMode.hotSeat);
      await toDeckStep(cubit);
      await cubit.confirmDeck();

      expect(cubit.back(), isTrue);

      final state = now(cubit);
      expect(state.seat, Seat.one);
      expect(state.step, SetupStep.deck);
      expect(state.faction.id, Small.skellige);
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
      expect(now(cubit).step, SetupStep.faction);
      expect(cubit.back(), isTrue, reason: 'против бота перед фракцией стоит сложность');
      expect(now(cubit).step, SetupStep.difficulty);
      expect(cubit.back(), isFalse);
      expect(now(cubit).step, SetupStep.difficulty);
    });

    test('в hot-seat с выбора фракции назад некуда', () async {
      final cubit = build(LocalMatchMode.hotSeat);
      await ready(cubit);

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

      await cubit.confirmFaction();

      expect(cubit.state, isA<MatchSetupFailed>());
    });

    test('закрытый держатель не падает на позднем ответе', () async {
      await repository.save(smallSkelligeDeck());
      final cubit = build(LocalMatchMode.vsBot);
      await ready(cubit);

      final pending = cubit.confirmFaction();
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

/// Хранилище настроек, которое не читается и не пишется.
final class _BrokenSettingsRepository extends InMemorySettingsRepository {
  @override
  Stream<AppSettings> watch() => Stream.error(StateError('настройки недоступны'));

  @override
  Future<void> save(AppSettings settings) => Future.error(StateError('настройки недоступны'));
}
