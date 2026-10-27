import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/campaign/application/watch_campaign_summary.dart';
import 'package:gwent/src/features/campaign/domain/campaign_summary.dart';
import 'package:gwent/src/features/deck_builder/application/watch_decks.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/menu/application/load_menu.dart';
import 'package:gwent/src/features/menu/presentation/menu_state.dart';
import 'package:gwent/src/features/sound/application/play_sound.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';
import 'package:gwent/src/features/tutorial/application/watch_first_match_passed.dart';

/// Держатель главного меню: заставка при запуске, затем меню, которое знает, можно ли играть.
///
/// Заставка показывается, пока [LoadMenu] готовит данные, и не короче [minSplash]: иначе она мелькнула бы и исчезла.
/// После этого держатель следит за списком колод: пока колод нет (или набор карт не загрузился), играть нельзя и
/// меню зовёт в конструктор. Держатель живёт всё время работы приложения, поэтому заставка идёт один раз.
///
/// Если задан [WatchFirstMatchPassed], меню знает, прошёл ли игрок «Первую партию», и метит «Обучение» словом «Новое».
final class MenuCubit extends Cubit<MenuState> {
  /// Создаёт держатель и сразу начинает готовить меню.
  MenuCubit(
    this._loadMenu,
    this._watchDecks, {
    this.minSplash = const Duration(milliseconds: 1200),
    PlaySound? sound,
    WatchFirstMatchPassed? watchFirstMatchPassed,
    WatchCampaignSummary? watchCampaignSummary,
  }) : _sound = sound,
       _watchFirstMatchPassed = watchFirstMatchPassed,
       _watchCampaignSummary = watchCampaignSummary,
       super(const MenuLoading()) {
    unawaited(_load());
  }

  final LoadMenu _loadMenu;
  final WatchDecks _watchDecks;
  final PlaySound? _sound;
  final WatchFirstMatchPassed? _watchFirstMatchPassed;
  final WatchCampaignSummary? _watchCampaignSummary;

  /// Наименьшее время заставки.
  final Duration minSplash;

  StreamSubscription<List<Deck>>? _subscription;
  StreamSubscription<bool>? _passedSubscription;
  StreamSubscription<CampaignSummary?>? _campaignSubscription;
  CampaignSummary? _campaign;
  MenuInfo? _info;
  bool _hasDeck = false;

  /// Без слежения за флагом меню считает обучение пройденным: марки «Новое» нет.
  bool _firstMatchPassed = true;
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
    await Future.wait([_watchPassed(), _watchCampaign()]);
    if (isClosed) {
      // Меню закрыли, пока ждали первых значений: `close` ещё не видел этих подписок.
      unawaited(_passedSubscription?.cancel());
      unawaited(_campaignSubscription?.cancel());
      return;
    }
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

  /// Следит за сводкой кампании для кнопки «Кампания» и ждёт её первого значения: кнопка стоит первой в колонке, и
  /// если она появится позже меню, остальные кнопки сдвинутся. Сбой чтения кнопку не ломает: её просто нет.
  Future<void> _watchCampaign() async {
    final watch = _watchCampaignSummary;
    if (watch == null) return;
    _campaignSubscription = await _listenFirst(watch(), (summary) => _campaign = summary);
  }

  /// Подписывается на флаг «Первая партия пройдена» и ждёт его первого значения, чтобы марка «Новое» не мигнула.
  Future<void> _watchPassed() async {
    final watch = _watchFirstMatchPassed;
    if (watch == null) return;
    _passedSubscription = await _listenFirst(watch(), (passed) => _firstMatchPassed = passed);
  }

  /// Слушает [stream], записывая значения через [store], и завершается, когда пришло первое значение, поток
  /// закончился или сломался: меню открывается и без него. После открытия меню новые значения перерисовывают его.
  Future<StreamSubscription<T>?> _listenFirst<T>(Stream<T> stream, void Function(T value) store) async {
    final first = Completer<void>();
    void release() {
      if (!first.isCompleted) first.complete();
    }

    StreamSubscription<T>? subscription;
    try {
      subscription = stream.listen(
        (value) {
          store(value);
          if (state is MenuReady) _emitReady();
          release();
        },
        onError: (Object error, StackTrace stackTrace) {
          addError(error, stackTrace);
          release();
        },
        onDone: release,
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      release();
    }
    await first.future;
    return subscription;
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
        firstMatchPassed: _firstMatchPassed,
        campaign: _campaign,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _passedSubscription?.cancel();
    await _campaignSubscription?.cancel();
    return super.close();
  }
}
