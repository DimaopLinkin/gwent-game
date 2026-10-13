import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/deck_builder/application/ensure_starter_decks.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;

/// Держатель выбора перед партией: режим (hot-seat или против бота) и колода каждого места.
///
/// Готовый выбор отдаёт `MatchSetupReady.request`, его экран передаёт держателю партии. Если выбранную колоду
/// удалили, выбор места сбрасывается.
///
/// С [ensureStarterDecks] держатель сначала даёт каждой фракции стартовую колоду, а с [preselect] ставит на оба
/// места первую колоду списка, пока игрок не выбрал сам: так партию можно начать одним нажатием.
final class MatchSetupCubit extends Cubit<MatchSetupState> {
  /// Создаёт держатель и сразу начинает читать колоды.
  MatchSetupCubit(
    WatchDecks watchDecks, {
    LocalMatchMode mode = LocalMatchMode.vsBot,
    EnsureStarterDecks? ensureStarterDecks,
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
    if (ensureStarterDecks != null) unawaited(_ensure(ensureStarterDecks));
  }

  late final StreamSubscription<void> _subscription;
  LocalMatchMode _mode;
  final bool _preselect;
  final Map<Seat, String> _chosen = {};
  List<Deck> _decks = const [];
  bool _loaded = false;

  /// Выбирает режим.
  void selectMode(LocalMatchMode mode) {
    _mode = mode;
    _emitReady();
  }

  /// Выбирает колоду [deckId] для места [seat]. Колоды, которой нет в списке, выбрать нельзя.
  void selectDeck(Seat seat, String deckId) {
    if (!_decks.any((deck) => deck.id == deckId)) return;
    _chosen[seat] = deckId;
    _emitReady();
  }

  Future<void> _ensure(EnsureStarterDecks ensureStarterDecks) async {
    try {
      await ensureStarterDecks();
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(MatchSetupFailed(error));
    }
  }

  void _onDecks(List<Deck> decks) {
    _loaded = true;
    _decks = decks;
    final ids = {for (final deck in decks) deck.id};
    _chosen.removeWhere((_, deckId) => !ids.contains(deckId));
    if (_preselect && decks.isNotEmpty) {
      for (final seat in Seat.values) {
        _chosen.putIfAbsent(seat, () => decks.first.id);
      }
    }
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
