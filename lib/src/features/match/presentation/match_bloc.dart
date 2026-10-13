import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/awaited_action.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match/presentation/match_event.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Держатель состояния экрана партии: от выбранных колод до итога.
///
/// Работает с партией только через `MatchTable`, поэтому одинаково ведёт hot-seat, игру против бота и (позже)
/// сетевую игру. Действия игрока уходят на стол за место, которое сейчас держит телефон.
///
/// Начало партии идёт по порядку макета: знакомство ([MatchIntro]), жребий или итог выбора Скоя'таэлей
/// ([MatchToss]), затем пересдача. Оба экрана нейтральные, рук на них нет; стол за это время идёт сам, а то, что он
/// прислал, копится и показывается после.
///
/// В hot-seat телефон переходит к тому, от кого партия ждёт действия; перед этим экран прячет руку
/// ([MatchHandover]). События копятся отдельно для каждого места и отдаются, когда место снова на экране.
/// Законченная партия записывается в историю; местную партию можно повторить (реванш).
final class MatchBloc extends Bloc<MatchEvent, MatchScreenState> {
  /// Создаёт держатель над сценариями.
  MatchBloc(this._startMatch, this._recordFinishedMatch) : super(const MatchIdle()) {
    on<MatchStartRequested>(_onStartRequested);
    on<MatchSessionOpened>(_onSessionOpened);
    on<MatchIntentSubmitted>(_onIntentSubmitted);
    on<MatchHandoverAccepted>(_onHandoverAccepted);
    on<MatchIntroFinished>(_onIntroFinished);
    on<MatchTossFinished>(_onTossFinished);
    on<MatchRematchRequested>(_onRematchRequested);
    on<MatchTableUpdated>(_onTableUpdated);
  }

  final StartMatch _startMatch;
  final RecordFinishedMatch _recordFinishedMatch;

  MatchSession? _session;
  StreamSubscription<TableUpdate>? _subscription;

  /// Последняя проекция каждого здешнего места.
  final Map<Seat, PlayerView> _views = {};

  /// События, которых место ещё не видело.
  final Map<Seat, List<GameEvent>> _unseen = {};

  /// Чьими глазами экран показывает партию; `null`, пока партия не на экране.
  Seat? _shown;

  /// Состав партии: собирается по первым проекциям.
  MatchRoster? _roster;

  /// Запрос, которым начата местная партия: по нему можно сыграть реванш.
  LocalMatchRequest? _request;

  bool _introDone = false;
  bool _tossDone = false;

  /// Поле уже показывали: передача телефона перед первым ходом называется иначе, чем передача между ходами.
  bool _boardShown = false;

  /// Держатель закрывается: новые столы сразу закрываются, состояния не меняются.
  bool _closing = false;

  Future<void> _onStartRequested(MatchStartRequested event, Emitter<MatchScreenState> emit) async {
    if (state is! MatchIdle && state is! MatchStartFailed) return;
    await _start(event.request, emit);
  }

  Future<void> _start(LocalMatchRequest request, Emitter<MatchScreenState> emit) async {
    _request = request;
    emit(const MatchStarting());
    final StartMatchResult result;
    try {
      result = await _startMatch(request);
    } on Object catch (error, stackTrace) {
      // Сбой хранилища или контента, а не причина из итога сценария: повторять бесполезно.
      if (!_closing) emit(MatchCrashed(error));
      addError(error, stackTrace);
      return;
    }
    switch (result) {
      case MatchStarted(:final session):
        await _open(session, emit);
      case MatchContentUnavailable() || MatchDeckNotFound() || MatchDeckInvalid():
        if (!_closing) emit(MatchStartFailed(result));
    }
  }

  Future<void> _onSessionOpened(MatchSessionOpened event, Emitter<MatchScreenState> emit) async {
    if (state is! MatchIdle && state is! MatchStartFailed) {
      // Партия уже идёт: вторую не открываем, но и стол не бросаем.
      await event.session.table.close();
      return;
    }
    await _open(event.session, emit);
  }

  /// Начинает следить за столом партии. Если держатель уже закрывается (игрок ушёл с экрана во время старта),
  /// закрывает стол, чтобы бот не ходил дальше без экрана.
  Future<void> _open(MatchSession session, Emitter<MatchScreenState> emit) async {
    if (_closing) {
      await session.table.close();
      return;
    }
    _session = session;
    _subscription = session.table.updates.listen((update) => add(MatchTableUpdated(update)));
  }

  void _onIntentSubmitted(MatchIntentSubmitted event, Emitter<MatchScreenState> emit) {
    final seat = _shown;
    if (state is! MatchInProgress || seat == null) return;
    _session!.table.submit(seat, event.intent);
  }

  void _onHandoverAccepted(MatchHandoverAccepted event, Emitter<MatchScreenState> emit) {
    if (state case MatchHandover(:final next)) _show(next, emit);
  }

  Future<void> _onIntroFinished(MatchIntroFinished event, Emitter<MatchScreenState> emit) async {
    if (state is! MatchIntro) return;
    _introDone = true;
    await _present(emit, leaving: true);
  }

  Future<void> _onTossFinished(MatchTossFinished event, Emitter<MatchScreenState> emit) async {
    if (state is! MatchToss) return;
    _tossDone = true;
    await _present(emit, leaving: true);
  }

  Future<void> _onRematchRequested(MatchRematchRequested event, Emitter<MatchScreenState> emit) async {
    final request = _request;
    if (state is! MatchFinished || request == null) return;
    await _subscription?.cancel();
    _subscription = null;
    await _session?.table.close();
    _session = null;
    _views.clear();
    _unseen.clear();
    _shown = null;
    _roster = null;
    _introDone = false;
    _tossDone = false;
    _boardShown = false;
    await _start(request, emit);
  }

  Future<void> _onTableUpdated(MatchTableUpdated event, Emitter<MatchScreenState> emit) async {
    switch (event.update) {
      case ViewsChanged(:final views, :final events):
        _views.addAll(views);
        for (final MapEntry(key: seat, value: seatEvents) in events.entries) {
          (_unseen[seat] ??= []).addAll(seatEvents);
        }
        await _present(emit);
      case IntentRefused(:final seat, :final reject):
        if (seat == _shown && state is MatchInProgress) {
          emit(
            MatchInProgress(
              view: _views[seat]!,
              content: _session!.content,
              roster: _roster!,
              events: const [],
              refusal: reject,
            ),
          );
        }
      case TableFailed(:final error):
        if (state is MatchFinished || state is MatchCrashed) return;
        emit(MatchCrashed(error));
        // Партия прервана: дальше стол ничего не показывает и не принимает.
        await _subscription?.cancel();
        _subscription = null;
        await _session!.table.close();
    }
  }

  /// Показывает партию тому, кто должен действовать, или передаёт ему телефон.
  ///
  /// Знакомство, жребий и передача телефона держатся, пока игрок их не закроет: новые данные стола их не сменяют.
  /// Закрытие знакомства или жребия ([leaving]) идёт дальше.
  Future<void> _present(Emitter<MatchScreenState> emit, {bool leaving = false}) async {
    final session = _session!;
    final local = session.table.localSeats;
    if (state is MatchFinished || state is MatchCrashed) return;
    final shown = _shown;
    if (_views.values.first.phase == MatchPhase.finished) {
      await _finish(emit, shown ?? session.perspective);
      return;
    }
    if (!leaving && (state is MatchHandover || state is MatchIntro || state is MatchToss)) return;
    final roster = _roster ??= MatchRoster.of(session, _views);
    if (!_introDone) {
      emit(MatchIntro(roster));
      return;
    }
    if (!_tossDone) {
      if (_unseenFirstPlayer() case final first?) {
        emit(MatchToss(roster: roster, first: first.seat, byChoice: first.byChoice));
        return;
      }
    }
    final next = _actor(local) ?? shown ?? session.perspective;
    if (local.length > 1 && next != shown) {
      // Hot-seat: телефон уходит другому игроку, в том числе в начале партии; руку видит только он.
      emit(MatchHandover(next, kind: _handoverKind(_views[next]!), roster: roster));
      return;
    }
    _show(next, emit);
  }

  /// Решение о первом игроке, которое ещё не показано жребием, или `null`.
  FirstPlayerChosen? _unseenFirstPlayer() {
    for (final events in _unseen.values) {
      for (final event in events) {
        if (event is FirstPlayerChosen) return event;
      }
    }
    return null;
  }

  HandoverKind _handoverKind(PlayerView view) => switch (view) {
    PlayerView(choice: PendingChoice(kind: ChoiceKind.firstPlayer)) => HandoverKind.firstPlayerChoice,
    PlayerView(phase: MatchPhase.redraw) => HandoverKind.redraw,
    _ when !_boardShown => HandoverKind.firstMove,
    _ => HandoverKind.turn,
  };

  /// Здешнее место, от которого партия ждёт действия; текущее, если ждут и от него (пересдача у обоих).
  Seat? _actor(Set<Seat> local) {
    final shown = _shown;
    if (shown != null && awaitsAction(_views[shown]!)) return shown;
    for (final seat in Seat.values) {
      if (local.contains(seat) && awaitsAction(_views[seat]!)) return seat;
    }
    return null;
  }

  void _show(Seat seat, Emitter<MatchScreenState> emit) {
    _shown = seat;
    final view = _views[seat]!;
    if (view.phase == MatchPhase.playing) _boardShown = true;
    emit(
      MatchInProgress(view: view, content: _session!.content, roster: _roster!, events: _takeUnseen(seat)),
    );
  }

  List<GameEvent> _takeUnseen(Seat seat) {
    final events = _unseen[seat] ?? const [];
    _unseen[seat] = [];
    return events;
  }

  Future<void> _finish(Emitter<MatchScreenState> emit, Seat seat) async {
    _shown = seat;
    final view = _views[seat]!;
    final events = _takeUnseen(seat);
    final roster = _roster ??= MatchRoster.of(_session!, _views);
    final canRematch = _request != null;
    emit(MatchFinished(view: view, roster: roster, events: events, canRematch: canRematch));
    try {
      final record = await _recordFinishedMatch(_session!, view);
      emit(MatchFinished(view: view, roster: roster, events: events, record: record, canRematch: canRematch));
    } on Object catch (error, stackTrace) {
      // Итог партии важнее записи в историю: экран остаётся на итоге, ошибка уходит в журнал.
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    await _subscription?.cancel();
    await _session?.table.close();
    return super.close();
  }
}
