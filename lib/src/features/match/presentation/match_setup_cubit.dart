import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/deck_builder/application/get_active_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/application/set_active_deck.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/match/application/choose_opponent_deck.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent/src/features/settings/application/load_bot_difficulty.dart';
import 'package:gwent/src/features/settings/application/save_bot_difficulty.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;
import 'package:gwent_engine/gwent_engine.dart' show Seat;

/// Держатель выбора перед партией (макет 7): фракция, лидер и колода каждого места.
///
/// Места выбирают по очереди: в hot-seat сначала первое, потом второе, против бота только первое, а колоду бота
/// даёт [ChooseOpponentDeck]. Каждое место проходит три шага: фракция → лидер → колода этой фракции. Лидер,
/// выбранный на втором шаге, идёт в партию вместо лидера колоды и не меняет сохранённую колоду. Против бота
/// перед ними стоит шаг сложности бота: выбранный уровень запоминается (ADR 0021).
///
/// Когда выбрано последнее место, состояние становится `MatchSetupDone` с запросом на партию.
final class MatchSetupCubit extends Cubit<MatchSetupState> {
  /// Создаёт держатель и сразу начинает читать правила и колоды.
  MatchSetupCubit({
    required WatchDecks watchDecks,
    required LoadDeckRules loadDeckRules,
    required GetActiveDeck getActiveDeck,
    required SetActiveDeck setActiveDeck,
    required ChooseOpponentDeck chooseOpponentDeck,
    required LoadBotDifficulty loadBotDifficulty,
    required SaveBotDifficulty saveBotDifficulty,
    required LocalMatchMode mode,
  }) : _getActiveDeck = getActiveDeck,
       _setActiveDeck = setActiveDeck,
       _chooseOpponentDeck = chooseOpponentDeck,
       _saveBotDifficulty = saveBotDifficulty,
       _mode = mode,
       _step = mode == LocalMatchMode.vsBot ? SetupStep.difficulty : SetupStep.faction,
       super(const MatchSetupLoading()) {
    _subscription = watchDecks().listen(
      _onDecks,
      onError: _fail,
    );
    unawaited(_loadRules(loadDeckRules, loadBotDifficulty));
  }

  final GetActiveDeck _getActiveDeck;
  final SetActiveDeck _setActiveDeck;
  final ChooseOpponentDeck _chooseOpponentDeck;
  final SaveBotDifficulty _saveBotDifficulty;
  final LocalMatchMode _mode;
  late final StreamSubscription<void> _subscription;

  DeckRules? _rules;
  List<Deck>? _decks;
  Seat _seat = Seat.one;
  SetupStep _step;
  BotDifficulty _difficulty = BotDifficulty.normal;
  int _factionIndex = 0;
  String? _leaderId;
  String? _deckId;
  bool _busy = false;
  bool _done = false; // выбор закончен или сорвался: состояние больше не меняется

  /// Что выбрало первое место, когда выбирает второе.
  ({String deckId, String leaderId, String factionId})? _firstSeat;

  /// Выбирает уровень сложности бота [difficulty] на шаге сложности.
  void selectDifficulty(BotDifficulty difficulty) {
    if (_step != SetupStep.difficulty || difficulty == _difficulty) return;
    _difficulty = difficulty;
    _emit();
  }

  /// Подтверждает уровень сложности: запоминает его и открывает выбор фракции.
  Future<void> confirmDifficulty() async {
    if (_rules == null || _step != SetupStep.difficulty || _busy) return;
    _busy = true;
    _emit();
    try {
      await _saveBotDifficulty(_difficulty);
      if (isClosed) return;
      _step = SetupStep.faction;
    } on Object catch (error, stackTrace) {
      _fail(error, stackTrace);
      return;
    } finally {
      _busy = false;
    }
    _emit();
  }

  /// Показывает фракцию номер [index] среди фракций пакета. Лидер и колода прежней фракции сбрасываются.
  void showFaction(int index) {
    final rules = _rules;
    if (rules == null || _step != SetupStep.faction || index == _factionIndex) return;
    if (index < 0 || index >= rules.factionInfos.length) return;
    _factionIndex = index;
    _leaderId = null;
    _deckId = null;
    _emit();
  }

  /// Подтверждает фракцию: открывает её лидеров. Выбран первый доступный лидер, если игрок не выбирал прежде.
  void confirmFaction() {
    final rules = _rules;
    if (rules == null || _step != SetupStep.faction || _busy) return;
    final faction = rules.factionInfos[_factionIndex];
    _leaderId ??= faction.leaders.where((leader) => leader.available).firstOrNull?.id;
    _step = SetupStep.leader;
    _emit();
  }

  /// Выбирает лидера [leaderId] выбранной фракции, чтобы прочитать его способность. Лидера другой фракции выбрать
  /// нельзя; недоступного можно выбрать, но подтвердить нельзя ([confirmLeader]).
  void selectLeader(String leaderId) {
    final rules = _rules;
    if (rules == null || _step != SetupStep.leader) return;
    if (rules.factionInfos[_factionIndex].leader(leaderId) == null) return;
    _leaderId = leaderId;
    _emit();
  }

  /// Подтверждает лидера: открывает колоды фракции.
  ///
  /// Если у фракции нет годной колоды, стартовая создаётся здесь (`GetActiveDeck`), поэтому список не пустой. Выбрана
  /// активная колода фракции, если она годится с этим лидером, иначе первая годная колода списка.
  Future<void> confirmLeader() async {
    final rules = _rules;
    final leaderId = _leaderId;
    if (rules == null || leaderId == null || _step != SetupStep.leader || _busy) return;
    final faction = rules.factionInfos[_factionIndex];
    if (faction.leader(leaderId)?.available != true) return;
    _busy = true;
    _emit();
    try {
      final active = await _getActiveDeck(faction.id);
      if (isClosed) return;
      // Поток колод может не успеть отдать стартовую колоду, созданную только что.
      final known = _decks ?? const <Deck>[];
      if (!known.any((deck) => deck.id == active.id)) _decks = [...known, active];
      _step = SetupStep.deck;
      _deckId = _preselect(rules, activeId: active.id);
    } on Object catch (error, stackTrace) {
      _fail(error, stackTrace);
      return;
    } finally {
      _busy = false;
    }
    _emit();
  }

  /// Выбирает колоду [deckId] из списка. Колоды, которой нет в списке фракции, выбрать нельзя.
  void selectDeck(String deckId) {
    if (_step != SetupStep.deck || !_factionDecks().any((deck) => deck.id == deckId)) return;
    _deckId = deckId;
    _emit();
  }

  /// Подтверждает колоду, годную в партию. Дальше идёт следующее место или, у последнего, начинается партия.
  ///
  /// Выбранная колода становится активной колодой своей фракции (`SetActiveDeck`): в следующий раз она выбрана заранее.
  Future<void> confirmDeck() async {
    final rules = _rules;
    final leaderId = _leaderId;
    final deckId = _deckId;
    if (rules == null || leaderId == null || deckId == null || _step != SetupStep.deck || _busy) return;
    final deck = _factionDecks().where((deck) => deck.id == deckId).firstOrNull;
    if (deck == null || rules.check(deck.copyWith(leaderId: leaderId)).isNotEmpty) return;
    _busy = true;
    _emit();
    try {
      await _rememberChoice(deck);
      if (isClosed) return;
      switch (_seat) {
        case Seat.one when _mode == LocalMatchMode.hotSeat:
          _firstSeat = (deckId: deck.id, leaderId: leaderId, factionId: deck.factionId);
          _seat = Seat.two;
          _step = SetupStep.faction;
          _leaderId = null;
          _deckId = null;
        case Seat.one:
          final opponent = await _chooseOpponentDeck(_difficulty);
          if (isClosed) return;
          _done = true;
          emit(
            MatchSetupDone(
              LocalMatchRequest(
                mode: _mode,
                deckOne: deck.id,
                deckTwo: opponent.id,
                leaderOne: leaderId,
                difficulty: _difficulty,
                opponentDeck: opponent,
              ),
            ),
          );
          return;
        case Seat.two:
          final first = _firstSeat!;
          _done = true;
          emit(
            MatchSetupDone(
              LocalMatchRequest(
                mode: _mode,
                deckOne: first.deckId,
                deckTwo: deck.id,
                leaderOne: first.leaderId,
                leaderTwo: leaderId,
              ),
            ),
          );
          return;
      }
    } on Object catch (error, stackTrace) {
      _fail(error, stackTrace);
      return;
    } finally {
      _busy = false;
    }
    _emit();
  }

  /// Возвращает на предыдущий шаг. `false`, если назад некуда: это первый шаг первого места, дальше выход в меню.
  bool back() {
    if (state is! MatchSetupReady) return false;
    // Пока идёт сохранение выбора, шаг не меняется, но и из экрана не выходят.
    if (_busy) return true;
    switch (_step) {
      case SetupStep.deck:
        _step = SetupStep.leader;
      case SetupStep.leader:
        _step = SetupStep.faction;
      case SetupStep.faction when _seat == Seat.two:
        // Возвращаемся на колоду первого места: оно выбрано заново, а второе место начинается с чистого шага.
        final first = _firstSeat!;
        _seat = Seat.one;
        _step = SetupStep.deck;
        _firstSeat = null;
        _factionIndex = _rules!.factionInfos.indexWhere((faction) => faction.id == first.factionId);
        _leaderId = first.leaderId;
        _deckId = first.deckId;
      case SetupStep.faction when _mode == LocalMatchMode.vsBot:
        _step = SetupStep.difficulty;
      case SetupStep.faction || SetupStep.difficulty:
        return false;
    }
    _emit();
    return true;
  }

  bool get _canStepBack => !(_seat == Seat.one && _step == _firstStep);

  /// Первый шаг выбора: против бота сложность, в hot-seat фракция.
  SetupStep get _firstStep => _mode == LocalMatchMode.vsBot ? SetupStep.difficulty : SetupStep.faction;

  Future<void> _loadRules(LoadDeckRules loadDeckRules, LoadBotDifficulty loadBotDifficulty) async {
    try {
      final rules = await loadDeckRules();
      // Уровень нужен только против бота.
      final difficulty = _mode == LocalMatchMode.vsBot ? await loadBotDifficulty() : BotDifficulty.normal;
      if (isClosed) return;
      if (rules.factionInfos.isEmpty) throw StateError('в пакете нет фракций с колодой');
      _rules = rules;
      _difficulty = difficulty;
      _emit();
    } on Object catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
  }

  /// Выбор сорвался: состояние становится ошибкой и больше не меняется.
  void _fail(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    if (isClosed || _done) return;
    _done = true;
    emit(MatchSetupFailed(error));
  }

  Future<void> _rememberChoice(Deck deck) async {
    try {
      await _setActiveDeck(deck.id);
    } on InvalidDeckException {
      // Колода годна только с выбранным лидером, а активной может стать лишь колода, годная со своим: выбор
      // партии это не отменяет, просто активная колода фракции остаётся прежней.
    }
  }

  void _onDecks(List<Deck> decks) {
    _decks = decks;
    if (state is MatchSetupReady && _step == SetupStep.deck && !_factionDecks().any((deck) => deck.id == _deckId)) {
      // Выбранную колоду удалили: выбор падает на первую годную колоду списка.
      _deckId = _rules == null ? null : _preselect(_rules!);
    }
    _emit();
  }

  /// Колоды выбранной фракции в порядке хранилища.
  List<Deck> _factionDecks() {
    final rules = _rules;
    final decks = _decks;
    if (rules == null || decks == null) return const [];
    final factionId = rules.factionInfos[_factionIndex].id;
    return [
      for (final deck in decks)
        if (deck.factionId == factionId) deck,
    ];
  }

  /// Колода, выбранная заранее: [activeId], если она годится с выбранным лидером, иначе первая годная, иначе первая.
  String? _preselect(DeckRules rules, {String? activeId}) {
    final leaderId = _leaderId;
    final decks = _factionDecks();
    bool fits(Deck deck) => leaderId != null && rules.check(deck.copyWith(leaderId: leaderId)).isEmpty;
    final ready = decks.where(fits);
    return decks.where((deck) => deck.id == activeId && fits(deck)).firstOrNull?.id ??
        ready.firstOrNull?.id ??
        decks.firstOrNull?.id;
  }

  void _emit() {
    final rules = _rules;
    final decks = _decks;
    if (rules == null || decks == null || isClosed || _done) return;
    final leaderId = _leaderId;
    emit(
      MatchSetupReady(
        mode: _mode,
        difficulty: _difficulty,
        seat: _seat,
        step: _step,
        rules: rules,
        factionIndex: _factionIndex,
        leaderId: leaderId,
        decks: [
          if (_step == SetupStep.deck && leaderId != null)
            for (final deck in _factionDecks())
              DeckChoice(
                deck: deck,
                issues: rules.check(deck.copyWith(leaderId: leaderId)),
              ),
        ],
        deckId: _deckId,
        canStepBack: _canStepBack,
        busy: _busy,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
