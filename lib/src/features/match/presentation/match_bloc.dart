import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/awaited_action.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match/domain/rematch_offer.dart';
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
/// Законченная партия записывается в историю; местную партию можно повторить (реванш). Сетевой реванш требует
/// согласия обоих: стол сообщает, что предложил соперник и не вышло ли время ([TableRematchChanged]), а когда оба
/// согласны, состояние становится [MatchRematchAgreed], и экран уходит в комнату выбирать колоды (ADR 0028).
final class MatchBloc extends Bloc<MatchEvent, MatchScreenState> {
  /// Создаёт держатель над сценариями.
  ///
  /// Сетевая партия уже начата вне экрана: [awaitingSession] ставит держатель в ожидание её стола
  /// (`MatchSessionOpened`), минуя выбор колод.
  MatchBloc(this._startMatch, this._recordFinishedMatch, {bool awaitingSession = false})
    : super(awaitingSession ? const MatchStarting() : const MatchIdle()) {
    on<MatchStartRequested>(_onStartRequested);
    on<MatchSessionOpened>(_onSessionOpened);
    on<MatchIntentSubmitted>(_onIntentSubmitted);
    on<MatchHandoverAccepted>(_onHandoverAccepted);
    on<MatchIntroFinished>(_onIntroFinished);
    on<MatchTossFinished>(_onTossFinished);
    on<MatchRematchRequested>(_onRematchRequested);
    on<MatchDeckChangeRequested>(_onDeckChangeRequested);
    on<MatchPauseChanged>(_onPauseChanged);
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

  /// Проекция каждого места перед обновлением, которым закончился раунд: поле раунда для подсчёта и ухода карт.
  final Map<Seat, PlayerView> _roundFields = {};

  /// Чьими глазами экран показывает партию; `null`, пока партия не на экране.
  Seat? _shown;

  /// Состав партии: собирается по первым проекциям.
  MatchRoster? _roster;

  /// Запрос, которым начата местная партия: по нему можно сыграть реванш.
  LocalMatchRequest? _request;

  /// Договорённость о реванше в сетевой партии; `null` у местной.
  RematchOffer? _offer;

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
    // Ожидание стола (`MatchStarting` без начатой партии и без запроса) тоже принимает сессию.
    final waiting = state is MatchStarting && _session == null && _request == null;
    if (_session != null || (state is! MatchIdle && state is! MatchStartFailed && !waiting)) {
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
    // Передача телефона, которая ждёт конца показа, сдаче не мешает: сдаётся тот, у кого телефон.
    if ((state is! MatchInProgress && state is! MatchHandover) || seat == null) return;
    _session!.table.submit(seat, event.intent);
  }

  void _onPauseChanged(MatchPauseChanged event, Emitter<MatchScreenState> emit) {
    if (_session?.table case final PausableTable table) table.setPaused(paused: event.paused);
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
    final table = _session?.table;
    if (table is RematchTable) {
      // Сетевая партия: слово за обоими, хост ответит обновлением стола.
      if (state is MatchFinished && (_offer ?? RematchOffer.idle).canRequest) table.requestRematch();
      return;
    }
    final request = _request;
    if (state is! MatchFinished || request == null) return;
    // Состояние меняется до первого await: повторное нажатие «Реванш» уже не пройдёт проверку выше.
    emit(const MatchStarting());
    await _closeSession();
    await _start(request, emit);
  }

  /// «Другая колода» на итоге местной партии: партия закрывается, экран возвращается к выбору фракции и колоды (его
  /// заново открывает `MatchSetupCubit.restart`, это делает экран).
  Future<void> _onDeckChangeRequested(MatchDeckChangeRequested event, Emitter<MatchScreenState> emit) async {
    if (state is! MatchFinished || _request == null || _session?.table is RematchTable) return;
    // Как у реванша: состояние меняется до первого await, повторное нажатие уже не пройдёт.
    emit(const MatchIdle());
    _request = null;
    await _closeSession();
  }

  /// Отпускает стол и всё, что накопилось за партию, чтобы следующая начиналась с чистого листа.
  Future<void> _closeSession() async {
    final subscription = _subscription;
    final oldSession = _session;
    _subscription = null;
    _session = null;
    _views.clear();
    _unseen.clear();
    _roundFields.clear();
    _shown = null;
    _roster = null;
    _introDone = false;
    _tossDone = false;
    _boardShown = false;
    await subscription?.cancel();
    await oldSession?.table.close();
  }

  Future<void> _onTableUpdated(MatchTableUpdated event, Emitter<MatchScreenState> emit) async {
    // Обновление прежнего стола пришло уже после реванша.
    if (_session == null) return;
    switch (event.update) {
      case ViewsChanged(:final views, :final events):
        for (final MapEntry(key: seat, value: seatEvents) in events.entries) {
          if (seatEvents.any((event) => event is RoundEnded)) {
            if (_views[seat] case final before?) _roundFields[seat] = before;
          }
          (_unseen[seat] ??= []).addAll(seatEvents);
        }
        _views.addAll(views);
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
      case TableRematchChanged(:final offer):
        _offer = offer;
        if (state case final MatchFinished finished) emit(finished.withRematch(offer));
      case TableRematchAgreed():
        if (state is! MatchFinished) return;
        // Стол свою работу закончил: игра ведёт следующую партию, а этот экран сейчас уйдёт в комнату.
        await _subscription?.cancel();
        _subscription = null;
        emit(const MatchRematchAgreed());
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
    if (shown != null && _redrawLastCardOf(shown)) {
      // Игрок поменял последнюю карту: пришедшую карту видно, прежде чем экран уйдёт на ожидание, передачу или поле.
      final replaced = (_unseen[shown] ?? const []).whereType<CardRedrawn>().toList();
      _unseen[shown] = (_unseen[shown] ?? const []).where((event) => event is! CardRedrawn).toList();
      emit(MatchRedrawSettled(view: _views[shown]!, roster: roster, events: replaced));
    }
    final next = _actor(local) ?? shown ?? session.perspective;
    if (local.length > 1 && next != shown) {
      // Hot-seat: телефон уходит другому игроку, в том числе в начале партии; руку видит только он.
      if (shown != null && _endsRoundFor(shown)) {
        // Раунд кончил тот, у кого телефон: поле, подсчёт и плашки остаются у него, а экран передачи ждёт в очереди
        // экрана партии до конца плашки хода (макет 13). Следующему игроку конец раунда не повторяется.
        _show(shown, emit);
      }
      emit(MatchHandover(next, kind: _handoverKind(_views[next]!), roster: roster));
      return;
    }
    _show(next, emit);
  }

  /// На экране пересдача [seat], и последней заменой он потратил все замены.
  bool _redrawLastCardOf(Seat seat) {
    final current = state;
    return current is MatchInProgress &&
        current.view.phase == MatchPhase.redraw &&
        !current.view.me.redrawDone &&
        _views[seat]!.me.redrawsLeft == 0 &&
        (_unseen[seat] ?? const []).any((event) => event is CardRedrawn);
  }

  /// Последнее действие [seat] закончило раунд, а партия продолжается: конец раунда этот игрок ещё не видел.
  bool _endsRoundFor(Seat seat) =>
      _views[seat]!.phase == MatchPhase.playing && (_unseen[seat] ?? const []).any((event) => event is RoundEnded);

  /// Конец раунда для [seat] уже показан другому игроку: из его непросмотренных событий уходит всё до начала нового
  /// раунда, поле раунда не нужно. Что сыграли после, остаётся.
  void _forgetRoundEnd(Seat seat) {
    final events = _unseen[seat];
    if (events != null) {
      final end = events.lastIndexWhere((event) => event is RoundEnded);
      if (end >= 0) _unseen[seat] = events.sublist(end + 1);
    }
    _roundFields.remove(seat);
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
    final events = _takeUnseen(seat);
    final closing = _takeClosing(seat, events);
    if (view.phase == MatchPhase.playing && events.any((event) => event is RoundEnded)) {
      // Конец раунда увидел этот игрок: другим местам он не повторяется.
      for (final other in _unseen.keys.where((other) => other != seat).toList()) {
        _forgetRoundEnd(other);
      }
    }
    emit(MatchInProgress(view: view, content: _session!.content, roster: _roster!, events: events, closing: closing));
  }

  /// Поле закончившегося раунда, если оно относится к [events].
  PlayerView? _takeClosing(Seat seat, List<GameEvent> events) {
    final closing = _roundFields.remove(seat);
    return events.any((event) => event is RoundEnded) ? closing : null;
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
    final closing = _takeClosing(seat, events);
    final roster = _roster ??= MatchRoster.of(_session!, _views);
    final canRematch = _request != null;
    final session = _session!;
    // Сначала поле с последним ходом и счётом: игрок видит, чем кончилась партия, а итог матча экран открывает после.
    if (_boardShown && events.any((event) => event is MatchEnded)) {
      emit(MatchInProgress(view: view, content: session.content, roster: roster, events: events, closing: closing));
    }
    emit(
      MatchFinished(view: view, roster: roster, events: events, canRematch: canRematch, rematch: _rematchOf(session)),
    );
    if (!session.recordsHistory) return;
    try {
      final record = await _recordFinishedMatch(session, view);
      // Пока писалась история, игрок мог начать реванш или уйти: итог прежней партии новое состояние не затирает.
      if (isClosed || !identical(_session, session)) return;
      emit(
        MatchFinished(
          view: view,
          roster: roster,
          events: events,
          record: record,
          canRematch: canRematch,
          rematch: _rematchOf(session),
        ),
      );
    } on Object catch (error, stackTrace) {
      // Итог партии важнее записи в историю: экран остаётся на итоге, ошибка уходит в журнал.
      addError(error, stackTrace);
    }
  }

  /// Договорённость о реванше для итога сетевой партии; у остальных `null`.
  RematchOffer? _rematchOf(MatchSession session) =>
      session.table is RematchTable ? (_offer ?? RematchOffer.idle) : null;

  @override
  Future<void> close() async {
    _closing = true;
    await _subscription?.cancel();
    await _session?.table.close();
    return super.close();
  }
}
