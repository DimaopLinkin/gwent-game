import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/deck_builder/application/ensure_starter_decks.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/match/application/choose_default_decks.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;

/// Держатель выбора перед партией: колода каждого места для режима [mode] (hot-seat или против бота; режим
/// выбирается в главном меню).
///
/// Готовый выбор отдаёт `MatchSetupReady.request`, его экран передаёт держателю партии. Если выбранную колоду
/// удалили, выбор места сбрасывается.
///
/// С [ensureStarterDecks] держатель сначала даёт каждой фракции стартовую колоду. Пока игрок не выбрал сам, на места
/// ставятся колоды по умолчанию ([chooseDefaultDecks]: активные колоды двух первых фракций), а без них, с
/// [preselect], первая колода списка: так партию можно начать одним нажатием.
final class MatchSetupCubit extends Cubit<MatchSetupState> {
  /// Создаёт держатель и сразу начинает читать колоды.
  MatchSetupCubit(
    WatchDecks watchDecks, {
    required LocalMatchMode mode,
    EnsureStarterDecks? ensureStarterDecks,
    ChooseDefaultDecks? chooseDefaultDecks,
    bool preselect = false,
  }) : _mode = mode,
       _preselect = preselect,
       super(const MatchSetupLoading()) {
    _subscription = watchDecks().listen(
      _onDecks,
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
        emit(MatchSetupFailed(error));
      },
    );
    if (ensureStarterDecks != null) unawaited(_prepare(ensureStarterDecks, chooseDefaultDecks));
  }

  late final StreamSubscription<void> _subscription;
  final LocalMatchMode _mode;
  final bool _preselect;
  final Map<Seat, String> _chosen = {};
  final Map<Seat, String> _defaults = {};
  List<Deck> _decks = const [];
  bool _loaded = false;

  /// Выбирает колоду [deckId] для места [seat]. Колоды, которой нет в списке, выбрать нельзя.
  void selectDeck(Seat seat, String deckId) {
    if (!_decks.any((deck) => deck.id == deckId)) return;
    _chosen[seat] = deckId;
    _emitReady();
  }

  Future<void> _prepare(EnsureStarterDecks ensureStarterDecks, ChooseDefaultDecks? chooseDefaultDecks) async {
    try {
      await ensureStarterDecks();
      final defaults = await chooseDefaultDecks?.call();
      if (defaults == null || isClosed) return;
      _defaults
        ..[Seat.one] = defaults.deckOne
        ..[Seat.two] = defaults.deckTwo;
      _preselectDecks();
      _emitReady();
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(MatchSetupFailed(error));
    }
  }

  /// Ставит на свободные места колоду по умолчанию, а без неё первую колоду списка.
  void _preselectDecks() {
    final ids = {for (final deck in _decks) deck.id};
    for (final seat in Seat.values) {
      if (_chosen.containsKey(seat)) continue;
      final byDefault = _defaults[seat];
      if (byDefault != null && ids.contains(byDefault)) {
        _chosen[seat] = byDefault;
      } else if (_preselect && _decks.isNotEmpty) {
        _chosen[seat] = _decks.first.id;
      }
    }
  }

  void _onDecks(List<Deck> decks) {
    _loaded = true;
    _decks = decks;
    final ids = {for (final deck in decks) deck.id};
    _chosen.removeWhere((_, deckId) => !ids.contains(deckId));
    _preselectDecks();
    _emitReady();
  }

  void _emitReady() {
    // Пока список колод не пришёл, выбор режима только запоминается.
    if (!_loaded) return;
    emit(MatchSetupReady(decks: _decks, mode: _mode, deckOne: _chosen[Seat.one], deckTwo: _chosen[Seat.two]));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
