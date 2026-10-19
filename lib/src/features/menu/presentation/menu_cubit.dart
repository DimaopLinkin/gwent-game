import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/menu/application/load_menu.dart';
import 'package:gwent/src/features/menu/presentation/menu_state.dart';
import 'package:gwent/src/features/sound/application/play_sound.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';

/// Держатель главного меню: заставка при запуске, затем меню, которое знает, можно ли играть.
///
/// Заставка показывается, пока [LoadMenu] готовит данные, и не короче [minSplash]: иначе она мелькнула бы и исчезла.
/// После этого держатель следит за списком колод: пока колод нет (или набор карт не загрузился), играть нельзя и
/// меню зовёт в конструктор. Держатель живёт всё время работы приложения, поэтому заставка идёт один раз.
final class MenuCubit extends Cubit<MenuState> {
  /// Создаёт держатель и сразу начинает готовить меню.
  MenuCubit(this._loadMenu, this._watchDecks, {this.minSplash = const Duration(milliseconds: 1200), PlaySound? sound})
    : _sound = sound,
      super(const MenuLoading()) {
    unawaited(_load());
  }

  final LoadMenu _loadMenu;
  final WatchDecks _watchDecks;
  final PlaySound? _sound;

  /// Наименьшее время заставки.
  final Duration minSplash;

  StreamSubscription<List<Deck>>? _subscription;
  MenuInfo? _info;
  bool _hasDeck = false;
  bool _opened = false;

  Future<void> _load() async {
    final minimum = Future<void>.delayed(minSplash);
    try {
      _info = await _loadMenu();
      if (_info?.starterDecksError case final Object error) addError(error, StackTrace.current);
    } on Object catch (error, stackTrace) {
      // Набор не прочитался: играть нельзя, но меню остаётся рабочим (колоды, настройки).
      addError(error, stackTrace);
    }
    await minimum;
    if (isClosed) return;
    try {
      _subscription = _watchDecks().listen(
        (decks) {
          _hasDeck = decks.isNotEmpty;
          _emitReady();
        },
        onError: (Object error, StackTrace stackTrace) {
          addError(error, stackTrace);
          _hasDeck = false;
          _emitReady();
        },
      );
    } on Object catch (error, stackTrace) {
      // Колоды не читаются: меню всё равно открывается, играть нельзя.
      addError(error, stackTrace);
      _emitReady();
    }
  }

  void _emitReady() {
    if (isClosed) return;
    final info = _info;
    // Звук открытия меню один раз: заставка кончилась и меню появилось.
    if (!_opened) {
      _opened = true;
      _sound?.call(SoundEffect.menuOpen);
    }
    emit(
      MenuReady(
        appVersion: info?.appVersion,
        packVersion: info?.packVersion,
        contentAvailable: info?.contentAvailable ?? false,
        hasDeck: _hasDeck,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
