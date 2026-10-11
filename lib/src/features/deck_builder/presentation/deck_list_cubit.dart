import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_list_state.dart';

/// Держатель состояния списка колод: подписывается на сценарий [WatchDecks].
final class DeckListCubit extends Cubit<DeckListState> {
  /// Создаёт держатель и сразу начинает читать колоды.
  DeckListCubit(WatchDecks watchDecks) : super(const DeckListLoading()) {
    _subscription = watchDecks().listen(
      (decks) => emit(DeckListLoaded(decks)),
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
        emit(DeckListFailed(error));
      },
    );
  }

  late final StreamSubscription<void> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
