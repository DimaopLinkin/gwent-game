import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/campaign/application/load_card_book.dart';
import 'package:gwent/src/features/campaign/presentation/card_book_state.dart';

/// Держатель «Книги карт»: читает открытые карты один раз при открытии экрана.
final class CardBookCubit extends Cubit<CardBookState> {
  /// Создаёт держатель и сразу начинает загрузку.
  CardBookCubit(this._load) : super(const CardBookLoading()) {
    unawaited(_start());
  }

  final LoadCardBook _load;

  Future<void> _start() async {
    try {
      final loaded = await _load();
      if (isClosed) return;
      emit(loaded == null ? const CardBookUnavailable() : CardBookReady(loaded));
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(const CardBookUnavailable());
    }
  }
}
