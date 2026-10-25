import 'dart:async';

import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/game_lobby.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match/domain/network_match_table.dart';
import 'package:gwent/src/features/match/domain/rematch_offer.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchMode;
import 'package:gwent/src/features/match_history/domain/replay_recorder.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';

/// Сетевая игра этого телефона: от комнаты ожидания до конца партии.
///
/// Хост держит партию ([MatchHost]) и объявляет её соседям, его собственный игрок подключён к ней тем же клиентом,
/// что и гость, только через память. Гость подключён по сети. Игра переводит события клиента в комнату
/// ([LobbyRoom]), пока партия не началась, а после начала отдаёт проекции столу ([openMatch]). Если у гостя
/// пропала связь, он подключается к хосту заново по тому же адресу, пока не пройдёт [reconnectWindow]. Решение: ADR 0019.
final class NetworkGame {
  /// Создаёт игру над клиентом.
  ///
  /// Хост передаёт [host] и [hosted]: игра принимает соединения и закрывает их вместе с собой. Гость передаёт
  /// [lobby] и [address]: по ним он возвращается к хосту после обрыва. Клиент уже должен быть подключён
  /// к транспорту после создания игры, иначе первые события пропадут.
  NetworkGame({
    required MatchClient client,
    required GameContent content,
    required Scheduler scheduler,
    required this.playerName,
    MatchHost? host,
    HostedGame? hosted,
    InMemoryMatchJournal? journal,
    GameLobby? lobby,
    GameAddress? address,
    this.reconnectWindow = const Duration(minutes: 2),
    this.retryInterval = const Duration(seconds: 2),
    this.mode = MatchMode.wifi,
  }) : _client = client,
       _content = content,
       _scheduler = scheduler,
       _host = host,
       _journal = journal,
       _hosted = hosted,
       _lobby = lobby,
       _address = address {
    _events = client.events.listen(_onEvent);
    if (host != null && hosted != null) {
      _pending = host.pendingGuest.listen(_onPendingGuest);
      _connections = hosted.connections.listen(
        host.accept,
        // Система закрыла приём соединений (например, iOS при сворачивании): новых гостей не будет.
        onDone: () {
          if (!_closed && _room.end == null && !_room.started) {
            _setRoom(_room.copyWith(end: const RoomConnectionLost()));
          }
        },
      );
    }
  }

  /// Имя этого игрока в игре.
  final String playerName;

  /// Сколько гость пытается вернуться к хосту после обрыва, прежде чем сдаться.
  final Duration reconnectWindow;

  /// Как часто гость повторяет попытку.
  final Duration retryInterval;

  /// Каким способом идёт партия: записывается в историю.
  final MatchMode mode;

  final MatchClient _client;
  final GameContent _content;
  final Scheduler _scheduler;
  final MatchHost? _host;
  final InMemoryMatchJournal? _journal;
  final HostedGame? _hosted;
  final GameLobby? _lobby;
  final GameAddress? _address;

  late final StreamSubscription<ClientEvent> _events;
  StreamSubscription<Transport>? _connections;
  StreamSubscription<PendingGuest?>? _pending;
  final StreamController<LobbyRoom> _rooms = StreamController<LobbyRoom>.broadcast();

  /// Обновления для стола партии: копятся, пока стол не открыт, и первым идёт раздача. Реванш начинает новый
  /// стол с новым потоком ([_generation]).
  StreamController<TableUpdate> _table = StreamController<TableUpdate>();

  /// Номер партии в этой игре: растёт с каждым реваншем. Закрытие стола прежней партии новую не трогает.
  int _generation = 0;
  final Map<int, Intent> _intents = {};

  /// Последнее запрошенное состояние объявления хоста (открыто или занято); `null`, пока не менялось.
  bool? _requestedOpen;

  /// Хост пустил игрока, но о соперника в лобби ещё не объявлено: место занято. Без этого между «ожидающий снят»
  /// и «соперник появился» объявление открылось бы снова, а через интернет хост пересоздал бы комнату.
  bool _admitting = false;
  LobbyRoom _room = const LobbyRoom();
  PlayerView? _firstView;

  /// Запись идущей партии для истории: у хоста по журналу, у гостя по кадрам (ADR 0029). Новая на каждую партию.
  NetworkReplayRecorder? _recorder;
  int? _deckRequest;
  String? _deckName;
  Timer? _deadline;
  bool _reconnecting = false;
  bool _attempting = false;
  bool _closed = false;
  bool _handedOver = false;

  /// Партия закончилась и на экране итог: реванш и уход соперника видны на нём.
  bool _matchFinished = false;
  Completer<void>? _pause;
  Completer<LobbyRoom>? _settled;
  Timer? _settleTimer;

  /// Телефон создал эту игру.
  bool get isHost => _host != null;

  /// Игра идёт через интернет (комната с кодом), а не по Wi-Fi.
  bool get isOnline => mode == MatchMode.server;

  /// Название игры, которое видят соседи; `null` у гостя.
  String? get title => _hosted?.ad.hostName;

  /// Комната сейчас.
  LobbyRoom get room => _room;

  /// Изменения комнаты. Подписчик получает только новые; текущая комната — [room].
  Stream<LobbyRoom> get rooms => _rooms.stream;

  /// Игра закрыта.
  bool get isClosed => _closed;

  /// Ждёт, пока хост выдаст место или откажет; `null` в результате не бывает.
  ///
  /// Не дольше [timeout]: тогда комната заканчивается потерей связи. Нужна при подключении гостя.
  Future<LobbyRoom> settled(Duration timeout) {
    if (_isSettled(_room)) return Future.value(_room);
    final completer = _settled ??= Completer<LobbyRoom>();
    _settleTimer ??= _scheduler.timer(timeout, () => _setRoom(_room.copyWith(end: const RoomConnectionLost())));
    return completer.future;
  }

  bool _isSettled(LobbyRoom room) => room.link == RoomLink.online || room.end != null;

  /// Сообщает хосту, чем игрок занят: выбирает колоду, собирает или выбрал (с лидером [leader]).
  /// Готовность отменяется.
  void reportStage(LobbyStage stage, {LeaderId? leader}) {
    if (_closed || _room.started) return;
    _client.reportLobbyStatus(stage, leader: leader);
    _setRoom(
      _room.copyWith(
        myStage: stage,
        myLeader: leader,
        clearLeader: leader == null,
        clearCountdown: true,
        deckRefused: false,
      ),
    );
  }

  /// Отправляет колоду: игрок готов. Партия начнётся, когда готов и соперник. [deckName] попадёт на экран знакомства.
  void ready(Deck deck, {String? deckName}) {
    if (_closed || _room.started) return;
    _deckName = deckName;
    _deckRequest = _client.submitDeck(deck);
    _setRoom(_room.copyWith(myStage: LobbyStage.ready, myLeader: deck.leader, deckRefused: false));
  }

  /// Берёт колоду обратно: игрок больше не готов.
  void cancelReady() {
    if (_closed || _room.started || _room.myStage != LobbyStage.ready) return;
    _client.withdrawDeck();
    _setRoom(_room.copyWith(myStage: LobbyStage.chosen, clearCountdown: true));
  }

  /// Хост пускает игрока, который ждёт решения. Без ожидающего ничего не делает.
  void admitGuest() {
    if (_closed || _room.pendingGuest == null) return;
    if (_host?.pendingGuestNow?.seat case final seat?) {
      _admitting = true;
      _host?.admit(seat);
    }
  }

  /// Хост не пускает игрока, который ждёт решения: тот получает отказ. Без ожидающего ничего не делает.
  void declineGuest() {
    if (_closed || _room.pendingGuest == null) return;
    if (_host?.pendingGuestNow?.seat case final seat?) _host?.decline(seat);
  }

  /// Уходит из лобби. Хост закрывает партию для обоих, гость освобождает место.
  Future<void> leave() async {
    if (_closed) return;
    if (!isHost && !_room.started) _client.leaveLobby();
    await close();
  }

  /// Открывает партию для экрана: стол, который ведёт её, и сведения для истории. Игра передаёт стол
  /// держателю состояния экрана, закрывать её после этого должен он, закрыв стол.
  ///
  /// Бросает [StateError], если партия ещё не началась или игра закрыта.
  MatchSession openMatch() {
    final view = _firstView;
    final seat = _room.seat;
    if (_closed || view == null || seat == null) throw StateError('Партия ещё не началась');
    if (_handedOver) throw StateError('Партия уже открыта на экране');
    _handedOver = true;
    final deckName = _deckName;
    final generation = _generation;
    return MatchSession(
      mode: mode,
      table: NetworkMatchTable(
        seat: seat,
        updates: _table.stream,
        onSubmit: _send,
        // Стол прежней партии, закрытый после реванша, игру не закрывает: она уже ведёт следующую.
        onClose: () => generation == _generation ? close() : Future<void>.value(),
        onRematch: _requestRematch,
      ),
      content: _content,
      factionIds: {seat: _factionId(view.me.faction), seat.opponent: _factionId(view.opponent.faction)},
      deckNames: {seat: ?deckName},
      opponentName: _room.opponent?.name,
      recorder: _recorder,
    );
  }

  /// Адрес партии для приглашения по QR-коду; `null` у гостя и у закрытой игры.
  Future<GameAddress?> address() async {
    final hosted = _hosted;
    return _closed || hosted == null ? null : hosted.address();
  }

  /// Хост свернул приложение ([away]) или вернулся: гость видит паузу, пока связь жива. У гостя ничего не делает:
  /// его уход виден хосту как обрыв связи.
  void setAway({required bool away}) {
    final seat = _room.seat;
    if (_closed || seat == null) return;
    _host?.setAway(seat, away: away);
  }

  void _requestRematch() {
    if (_closed || !_matchFinished) return;
    _client.requestRematch();
  }

  /// Партию открыли для экрана: комната больше не нужна и не закрывает игру.
  bool get handedOver => _handedOver;

  /// Закрывает игру: соединения, объявление и подписки. Повторный вызов ничего не делает.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _deadline?.cancel();
    _settleTimer?.cancel();
    _wakePause();
    _reconnecting = false;
    if (_settled case final settled? when !settled.isCompleted) settled.complete(_room);
    await _events.cancel();
    await _connections?.cancel();
    await _pending?.cancel();
    await _client.close();
    await _host?.close();
    try {
      await _hosted?.close();
    } on Object {
      // Объявление могло пропасть вместе с сетью: закрытию это не мешает.
    }
    unawaited(_table.close());
    unawaited(_rooms.close());
  }

  void _send(Intent intent) {
    if (_closed) return;
    _intents[_client.send(intent)] = intent;
  }

  Ruleset get _ruleset {
    final manifest = _content.pack.manifest;
    return Ruleset(id: manifest.packId, hash: manifest.contentHash, engineVersion: engineVersion);
  }

  String _factionId(Faction faction) => _content.factions.entries.firstWhere((entry) => entry.value == faction).key;

  void _onEvent(ClientEvent event) {
    switch (event) {
      case Joined(:final seat):
        _reconnecting = false;
        _deadline?.cancel();
        _deadline = null;
        _setRoom(_room.copyWith(seat: seat, link: RoomLink.online, linkUnstable: false));
      case JoinRefused(:final reason):
        _reconnecting = false;
        _deadline?.cancel();
        _setRoom(_room.copyWith(end: RoomRefused(reason)));
      case ConnectionLost():
        _onConnectionLost();
      case RematchChanged(:final phase, :final window):
        if (_matchFinished) _tell(TableRematchChanged(_offerOf(phase, window)));
      case RematchStarted():
        _onRematchStarted();
      case ViewChanged(:final view, :final events):
        _onView(view, events);
      case ActionRefused(:final refusal, :final request):
        _onRefusal(refusal, request);
      case LinkQualityChanged(:final unstable):
        _setRoom(_room.copyWith(linkUnstable: unstable));
      case OpponentPresenceChanged(:final online, :final name, :final unstable, :final away):
        // Посреди партии из соперника меняется только связь: по ней экран показывает обрыв.
        if (_room.started) {
          if (_room.opponent case final opponent?) {
            _setRoom(
              _room.copyWith(
                opponent: opponent.copyWith(online: online, unstable: unstable, away: away),
              ),
            );
          }
          return;
        }
        final opponent = _room.opponent ?? RoomOpponent(name: name, online: online);
        _setRoom(
          _room.copyWith(
            opponent: opponent.copyWith(name: name, online: online, unstable: unstable, away: away),
          ),
        );
      case OpponentLobbyChanged(:final stage, :final leader):
        if (_room.started) return;
        final opponent = _room.opponent ?? const RoomOpponent(name: '', online: true);
        _setRoom(
          _room.copyWith(
            opponent: opponent.copyWith(stage: stage, leader: leader, clearLeader: leader == null),
          ),
        );
      case CountdownStarted(:final duration):
        if (!_room.started) _setRoom(_room.copyWith(countdown: duration));
      case CountdownCancelled():
        _setRoom(_room.copyWith(clearCountdown: true));
      case OpponentLeft():
        _setRoom(_room.copyWith(clearOpponent: true, clearCountdown: true));
      case GuestAdmitted():
        _setRoom(_room.copyWith(admitted: true));
      case LobbyClosed():
        _setRoom(_room.copyWith(end: const RoomHostClosed()));
      case HostDataInvalid():
        _reconnecting = false;
        _deadline?.cancel();
        _setRoom(_room.copyWith(end: const RoomHostInvalid(), clearCountdown: true));
        if (_room.started && !_table.isClosed) _table.add(const TableFailed(RoomHostInvalid()));
    }
  }

  RematchOffer _offerOf(RematchPhase phase, Duration window) => switch (phase) {
    RematchPhase.idle => RematchOffer.idle,
    RematchPhase.asked => RematchOffer(RematchStage.requested, window: window),
    RematchPhase.invited => RematchOffer(RematchStage.invited, window: window),
    RematchPhase.expired => const RematchOffer(RematchStage.expired),
    RematchPhase.opponentGone => const RematchOffer(RematchStage.opponentGone),
  };

  void _tell(TableUpdate update) {
    if (!_table.isClosed) _table.add(update);
  }

  /// Оба согласились на реванш: хост вернул партию в лобби. Стол прежней партии узнаёт об этом и закрывается, комната
  /// снова ждёт колоды обоих, а следующая партия откроется новым столом.
  void _onRematchStarted() {
    if (_closed || !_matchFinished) return;
    _tell(const TableRematchAgreed());
    unawaited(_table.close());
    _table = StreamController<TableUpdate>();
    _generation++;
    _matchFinished = false;
    _handedOver = false;
    _firstView = null;
    _recorder = null;
    _deckRequest = null;
    _deckName = null;
    _intents.clear();
    _setRoom(
      _room.copyWith(
        started: false,
        myStage: LobbyStage.choosing,
        clearLeader: true,
        clearCountdown: true,
        deckRefused: false,
        opponent: _room.opponent?.copyWith(stage: LobbyStage.choosing, clearLeader: true),
      ),
    );
  }

  void _onPendingGuest(PendingGuest? guest) {
    if (_closed) return;
    _setRoom(guest == null ? _room.copyWith(clearPendingGuest: true) : _room.copyWith(pendingGuest: guest.name));
  }

  void _onView(PlayerView view, List<GameEvent> events) {
    final seat = _client.seat ?? _room.seat;
    if (seat == null) return;
    _firstView ??= view;
    (_recorder ??= NetworkReplayRecorder(
      perspective: seat,
      ruleset: _ruleset,
      // Журнал хоста принадлежит партии, которая идёт сейчас; следующую партию начнёт реванш.
      journal: _journal,
    )).add(view, events);
    _matchFinished = view.phase == MatchPhase.finished;
    if (!_room.started) _setRoom(_room.copyWith(started: true, clearCountdown: true));
    if (!_table.isClosed) _table.add(ViewsChanged({seat: view}, {seat: events}));
  }

  void _onRefusal(Refusal refusal, int request) {
    if (request == _deckRequest) {
      _deckRequest = null;
      _setRoom(_room.copyWith(myStage: LobbyStage.chosen, clearCountdown: true, deckRefused: true));
      return;
    }
    final intent = _intents.remove(request);
    final reject = refusal.reject;
    final seat = _room.seat;
    if (intent != null && reject != null && seat != null && !_table.isClosed) {
      _table.add(IntentRefused(seat, intent, reject));
    }
  }

  void _onConnectionLost() {
    if (_closed || _room.end != null) return;
    if (_room.seat == null) {
      // Хост так и не выдал место: возвращаться не к чему.
      _setRoom(_room.copyWith(end: const RoomConnectionLost()));
      return;
    }
    _setRoom(_room.copyWith(link: RoomLink.lost, linkUnstable: false));
    // Хост пропал, пока на экране итог: реванша не будет, пока он не вернётся (его статус придёт после возвращения).
    if (_matchFinished && _host == null) _tell(const TableRematchChanged(RematchOffer(RematchStage.opponentGone)));
    if (_host != null || _lobby == null || _address == null) return;
    _reconnecting = true;
    _deadline ??= _scheduler.timer(reconnectWindow, _giveUp);
    unawaited(_attempt());
  }

  void _wakePause() {
    if (_pause case final pause? when !pause.isCompleted) pause.complete();
  }

  void _giveUp() {
    _deadline = null;
    if (!_reconnecting || _closed) return;
    _reconnecting = false;
    _wakePause();
    _setRoom(_room.copyWith(end: const RoomConnectionLost()));
    if (_room.started && !_table.isClosed) _table.add(const TableFailed(RoomConnectionLost()));
  }

  /// Пробует подключиться к хосту, пока не получится или не выйдет время. Результат подключения приходит событием
  /// клиента: `Joined` — вернулись, `ConnectionLost` — попытка не удалась и начнётся следующая.
  Future<void> _attempt() async {
    if (_attempting) return;
    _attempting = true;
    try {
      while (_reconnecting && !_closed) {
        try {
          final transport = await _lobby!.join(_address!);
          if (!_reconnecting || _closed) {
            await transport.close();
            return;
          }
          _client.connect(transport);
          return;
        } on LobbyException {
          // Хост ещё не вернулся: пробуем снова.
        }
        final pause = _pause = Completer<void>();
        final timer = _scheduler.timer(retryInterval, () {
          if (!pause.isCompleted) pause.complete();
        });
        await pause.future;
        timer.cancel();
      }
    } finally {
      _attempting = false;
    }
  }

  void _setRoom(LobbyRoom room) {
    if (_closed || room == _room) return;
    _room = room;
    if (room.opponent != null) _admitting = false;
    if (!_rooms.isClosed) _rooms.add(room);
    _syncAdvertisement();
    if (_isSettled(room)) {
      _settleTimer?.cancel();
      if (_settled case final settled? when !settled.isCompleted) settled.complete(room);
    }
  }

  /// Объявление открыто, пока в партии есть свободное место. Игрок, который ждёт решения хоста, место уже занял:
  /// отказ ему снова открывает объявление (через интернет это значит, что хост создаёт комнату заново, ADR 0026).
  void _syncAdvertisement() {
    final hosted = _hosted;
    if (hosted == null) return;
    final open = _room.opponent == null && _room.pendingGuest == null && !_admitting && !_room.started;
    // Сравниваем с последним запрошенным, а не с объявленным: объявление обновляется после `await`, и быстрый вход
    // с выходом гостя иначе оставил бы партию «занятой» при пустой комнате.
    if ((_requestedOpen ?? hosted.ad.open) == open) return;
    _requestedOpen = open;
    unawaited(
      hosted
          .advertise(hosted.ad.copyWith(open: open))
          .then<void>(
            (_) {},
            onError: (Object _) {
              // Не удалось обновить объявление: игра идёт, соседи просто увидят прежнее. Следующая смена повторит.
              _requestedOpen = null;
            },
          ),
    );
  }
}
