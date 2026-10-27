import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_play_state.dart';

/// Держатель справочника «Как играть»: достаёт набор карт для примеров. Справочник открывается и без него.
final class HowToPlayCubit extends Cubit<HowToPlayState> {
  /// Создаёт держатель и сразу начинает загрузку.
  HowToPlayCubit(this._loadContent) : super(const HowToPlayLoading()) {
    unawaited(_load());
  }

  final LoadGameContent _loadContent;

  Future<void> _load() async {
    try {
      final result = await _loadContent();
      if (isClosed) return;
      emit(switch (result) {
        GameContentReady(:final content) => HowToPlayReady(content),
        GameContentRejected() => const HowToPlayUnavailable(),
      });
    } on Object catch (error, stackTrace) {
      // Набор не прочитался: справочник остаётся текстовым.
      addError(error, stackTrace);
      if (!isClosed) emit(const HowToPlayUnavailable());
    }
  }
}
