import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/deck_builder/application/delete_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_state.dart';

/// Держатель списка колод: следит за хранилищем, подгружает правила набора карт и удаляет колоды.
final class DeckListCubit extends Cubit<DeckListState> {
  /// Создаёт держатель и сразу начинает читать колоды и правила.
  DeckListCubit(WatchDecks watchDecks, LoadDeckRules loadDeckRules, this._deleteDeck) : super(const DeckListLoading()) {
    _subscription = watchDecks().listen(
      (decks) {
        _decks = decks;
        _emit();
      },
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
        emit(DeckListFailed(error));
      },
    );
    unawaited(_loadRules(loadDeckRules));
  }

  final DeleteDeck _deleteDeck;
  late final StreamSubscription<void> _subscription;
  List<Deck>? _decks;
  DeckRules? _rules;
  bool _rulesDone = false;

  Future<void> _loadRules(LoadDeckRules loadDeckRules) async {
    try {
      _rules = await loadDeckRules();
    } on Object catch (error, stackTrace) {
      // Без набора карт колоды видны без фракций и лидеров, их по-прежнему можно удалить.
      addError(error, stackTrace);
    }
    _rulesDone = true;
    _emit();
  }

  void _emit() {
    final decks = _decks;
    if (decks == null || !_rulesDone || isClosed || state is DeckListFailed) return;
    emit(DeckListLoaded(decks, rules: _rules));
  }

  /// Удаляет колоду [id]. Список обновляется сам, по потоку хранилища; сбой удаления попадает в журнал.
  Future<void> delete(String id) async {
    try {
      await _deleteDeck(id);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
