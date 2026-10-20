import 'dart:async';
import 'dart:math';

import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/features/lobby/data/online/online_rooms.dart';
import 'package:gwent/src/features/lobby/data/online/room_channel.dart';
import 'package:gwent/src/features/lobby/data/online/room_message.dart';
import 'package:gwent/src/features/lobby/data/online/room_transport.dart';
import 'package:gwent/src/features/lobby/domain/found_game.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/game_lobby.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent_net/gwent_net.dart';

/// Лобби игры через интернет: комната на сервере и приватный канал Realtime (ADR 0025, 0026).
///
/// Телефон-хост остаётся хостом партии, как в Wi-Fi: сервер только пересылает кадры. Хост создаёт комнату и получает
/// код, гость входит по коду и подключается к хосту через канал комнаты. Каждое подключение гостя — отдельный
/// `Transport`, поэтому `MatchHost`, `MatchClient`, `NetworkGame` и переподключение по токену работают без изменений.
///
/// Поиска партий здесь нет: гость знает только код.
final class OnlineLobby implements GameLobby {
  /// Создаёт лобби над сервером комнат [rooms].
  OnlineLobby({
    required OnlineRooms rooms,
    required Scheduler scheduler,
    required Clock clock,
    Random? random,
    this.deadRoomMemory = const Duration(minutes: 1),
    this.closeLinger = const Duration(seconds: 10),
    this.standingRetry = const Duration(seconds: 30),
  }) : _rooms = rooms,
       _scheduler = scheduler,
       _clock = clock,
       _random = random ?? Random.secure();

  /// Сколько гость помнит, что комнаты больше нет, и не обращается за ней к серверу: каждый ответ «нет такой
  /// комнаты» засчитывается игроку как неверный код (лимит 8 за 10 минут), а возвращение к хосту повторяется
  /// каждые несколько секунд.
  final Duration deadRoomMemory;

  /// Сколько закрытая партия хоста ждёт, пока `MatchHost` закроет соединения, прежде чем оборвать их сама.
  final Duration closeLinger;

  /// Через сколько хост повторяет проверку комнаты, если сервер не ответил.
  final Duration standingRetry;

  final OnlineRooms _rooms;
  final Scheduler _scheduler;
  final Clock _clock;
  final Random _random;

  /// Комнаты, в которых этот телефон гость, по коду.
  final Map<String, _GuestRoom> _guestRooms = {};

  @override
  Future<HostedGame> host(GameAd ad) async {
    final room = await _rooms.create(ad);
    try {
      final channel = await _rooms.connect(room.id);
      if (!ad.open) await _rooms.setOpen(room.id, open: false);
      return _OnlineHostedGame(this, ad, room, channel);
    } on LobbyException {
      _closeQuietly(room.id);
      rethrow;
    }
  }

  /// Поиска нет: список всегда пуст, а поток остаётся открытым до отмены подписки.
  @override
  Stream<List<FoundGame>> discover() => Stream<List<FoundGame>>.multi((controller) => controller.add(const []));

  @override
  Future<Transport> join(GameAddress address) => switch (address) {
    OnlineAddress(:final code) => _join(code.value, address),
    LanAddress() => Future.error(const LobbyException(LobbyFailure.unreachable)),
  };

  Future<Transport> _join(String code, OnlineAddress address) async {
    var room = _guestRooms[code];
    if (room != null && room.deadSince != null && _clock.now().difference(room.deadSince!) >= deadRoomMemory) {
      _guestRooms.remove(code);
      room = null;
    }
    if (room == null) {
      final info = await _rooms.join(address.code);
      room = _guestRooms[code] = _GuestRoom(this, info);
    }
    return room.connect();
  }

  int _newCid() => _random.nextInt(1 << 32);

  /// Закрывает комнату на сервере, не дожидаясь ответа: комната без хозяина сама закроется по сроку.
  void _closeQuietly(String roomId) {
    unawaited(
      _rooms
          .close(roomId)
          .then<void>(
            (_) {},
            onError: (Object _) {
              // Сервер недоступен или комнаты уже нет: закрытию это не мешает.
            },
          ),
    );
  }
}

/// Комната, в которой телефон гость: канал открыт, пока есть хотя бы одно соединение.
final class _GuestRoom {
  _GuestRoom(this._lobby, this.info);

  final OnlineLobby _lobby;
  final RoomInfo info;

  /// Когда стало известно, что комнаты больше нет; `null`, пока считается живой.
  DateTime? deadSince;

  Future<RoomChannel>? _channel;
  StreamSubscription<RoomMessage>? _messages;
  final Map<int, RoomTransport> _transports = {};

  Future<Transport> connect() async {
    if (deadSince != null) throw const LobbyException(LobbyFailure.unreachable);
    final RoomChannel channel;
    try {
      channel = await _acquire();
    } on LobbyException catch (error) {
      throw await _explain(error);
    }
    var cid = _lobby._newCid();
    while (_transports.containsKey(cid)) {
      cid = _lobby._newCid();
    }
    final transport = RoomTransport(
      cid: cid,
      side: RoomSide.guest,
      send: channel.send,
      onClosed: _onClosed,
    );
    _transports[cid] = transport;
    return transport;
  }

  /// Открытый канал комнаты. Если, пока он открывался, последнее соединение закрылось и канал закрыт, открывает новый.
  Future<RoomChannel> _acquire() async {
    while (true) {
      final pending = _channel ??= _open();
      try {
        final channel = await pending;
        if (identical(_channel, pending)) return channel;
      } on LobbyException {
        if (identical(_channel, pending)) _channel = null;
        rethrow;
      }
    }
  }

  Future<RoomChannel> _open() async {
    final channel = await _lobby._rooms.connect(info.id);
    _messages = channel.messages.listen(_onMessage);
    return channel;
  }

  /// Вход в канал не удался: либо комнаты больше нет, либо нет связи с сервисом. Различает ответ сервера.
  Future<LobbyException> _explain(LobbyException error) async {
    try {
      if (await _lobby._rooms.standing(info.id) case RoomGone()) {
        deadSince = _lobby._clock.now();
        return const LobbyException(LobbyFailure.unreachable);
      }
    } on LobbyException catch (check) {
      return check;
    }
    return error;
  }

  void _onMessage(RoomMessage message) {
    if (message.from != RoomSide.host) return;
    final transport = _transports[message.cid];
    switch (message) {
      case FrameMessage(:final data):
        transport?.receive(data);
      case ByeMessage():
        transport?.peerClosed();
    }
  }

  void _onClosed(RoomTransport transport) {
    _transports.remove(transport.cid);
    if (_transports.isNotEmpty) return;
    // Канал живёт, пока есть соединение: новая попытка вернуться открывает свежий вход в канал.
    final channel = _channel;
    _channel = null;
    unawaited(_messages?.cancel());
    _messages = null;
    if (channel != null) unawaited(_closeChannel(channel));
  }

  Future<void> _closeChannel(Future<RoomChannel> channel) async {
    try {
      await (await channel).close();
    } on LobbyException {
      // Вход не удался: закрывать нечего.
      return;
    }
  }
}

/// Партия хоста: комната и канал.
///
/// Место гостя на сервере занимается один раз (ADR 0025), поэтому, когда гость ушёл и партия снова открыта
/// (`advertise` с `open: true`), хост создаёт комнату заново: у неё новый код и новый канал, а прежняя закрывается.
final class _OnlineHostedGame implements HostedGame {
  _OnlineHostedGame(this._lobby, this._ad, this._room, this._channel) {
    _attach(_channel);
    _watchExpiry();
  }

  /// Сколько подряд соединений гостя хост держит открытыми: честный гость держит одно, новое подключение
  /// заменяет прежнее, а лишние от одного гостя не должны копиться в памяти.
  static const int _maxConnections = 3;

  final OnlineLobby _lobby;
  GameAd _ad;
  RoomInfo _room;
  RoomChannel _channel;

  late final StreamController<Transport> _connections = StreamController<Transport>(onCancel: close);
  final Map<int, RoomTransport> _live = {};
  StreamSubscription<RoomMessage>? _messages;
  StreamSubscription<void>? _trouble;
  Timer? _expiry;
  Timer? _linger;
  bool _guestSeen = false;
  bool _closed = false;
  bool _gone = false;
  bool _checking = false;
  DateTime? _checkedAt;
  Future<void> _queue = Future<void>.value();

  @override
  GameAd get ad => _ad;

  @override
  Stream<Transport> get connections => _connections.stream;

  @override
  Future<GameAddress> address() => _serially(() async {
    if (_gone) throw const LobbyException(LobbyFailure.unavailable);
    return OnlineAddress(_room.code);
  });

  @override
  Future<void> advertise(GameAd ad) {
    if (ad.id != _ad.id) throw ArgumentError.value(ad.id, 'ad.id', 'Идентификатор партии менять нельзя');
    return _serially(() async {
      if (_closed) throw StateError('Партия закрыта');
      if (_gone) throw const LobbyException(LobbyFailure.unavailable);
      if (ad.open && _guestSeen) {
        await _renew();
      } else if (ad.open != _room.open) {
        await _lobby._rooms.setOpen(_room.id, open: ad.open);
        _room = _room.copyWith(open: ad.open);
      }
      _ad = ad;
    });
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _expiry?.cancel();
    unawaited(_connections.close());
    _lobby._closeQuietly(_room.id);
    if (_live.isEmpty) {
      await _release(_channel);
      return;
    }
    // Принятые соединения остаются открытыми: ими владеет `MatchHost`, например, чтобы отправить `LobbyClose`.
    // Канал закроется вместе с последним из них, а если хост партии их не закрыл, то по таймеру.
    _linger = _lobby._scheduler.timer(_lobby.closeLinger, () => unawaited(_release(_channel)));
  }

  void _attach(RoomChannel channel) {
    _channel = channel;
    _messages = channel.messages.listen(_onMessage);
    _trouble = channel.trouble.listen((_) => unawaited(_checkStanding(throttle: true)));
  }

  Future<void> _release(RoomChannel channel) async {
    _linger?.cancel();
    for (final transport in _live.values.toList()) {
      transport.abandon();
    }
    if (identical(channel, _channel)) {
      await _messages?.cancel();
      await _trouble?.cancel();
    }
    await channel.close();
  }

  void _onMessage(RoomMessage message) {
    if (message.from != RoomSide.guest) return;
    switch (message) {
      case FrameMessage(:final cid, :final data):
        final transport = _live[cid] ?? _accept(cid);
        transport?.receive(data);
      case ByeMessage(:final cid):
        _live[cid]?.peerClosed();
    }
  }

  /// Новое соединение гостя: его кадры идут новому `Transport`, который хост партии принимает как обычное
  /// подключение. Закрытая партия новых соединений не принимает.
  RoomTransport? _accept(int cid) {
    if (_closed || _gone) return null;
    while (_live.length >= _maxConnections) {
      _live.values.first.close().ignore();
    }
    final channel = _channel;
    final transport = RoomTransport(
      cid: cid,
      side: RoomSide.host,
      send: channel.send,
      onClosed: _onClosed,
    );
    _live[cid] = transport;
    _guestSeen = true;
    _connections.add(transport);
    return transport;
  }

  void _onClosed(RoomTransport transport) {
    if (identical(_live[transport.cid], transport)) _live.remove(transport.cid);
    if (_closed && _live.isEmpty) unawaited(_release(_channel));
  }

  /// Создаёт комнату заново для нового гостя. Сервер закрывает прежнюю при создании новой, поэтому при сбое хост
  /// остаётся в прежней комнате.
  Future<void> _renew() async {
    final room = await _lobby._rooms.create(_ad);
    final RoomChannel channel;
    try {
      channel = await _lobby._rooms.connect(room.id);
    } on LobbyException {
      _lobby._closeQuietly(room.id);
      rethrow;
    }
    final previous = _channel;
    await _messages?.cancel();
    await _trouble?.cancel();
    for (final transport in _live.values.toList()) {
      transport.abandon();
    }
    _room = room;
    _guestSeen = false;
    _attach(channel);
    _watchExpiry();
    await previous.close();
  }

  /// Комната закрывается сама по сроку, но канал об этом не узнаёт до очередной проверки доступа. В срок хост
  /// спрашивает сервер: если комнаты нет, код больше не работает, и партия заканчивается.
  void _watchExpiry() {
    _expiry?.cancel();
    final wait = _room.expiresAt.difference(_lobby._clock.now());
    _expiry = _lobby._scheduler.timer(wait < _lobby.standingRetry ? _lobby.standingRetry : wait, () {
      unawaited(_checkStanding());
    });
  }

  Future<void> _checkStanding({bool throttle = false}) async {
    if (_closed || _gone || _checking) return;
    final now = _lobby._clock.now();
    if (throttle && _checkedAt != null && now.difference(_checkedAt!) < _lobby.standingRetry) return;
    _checking = true;
    _checkedAt = now;
    try {
      switch (await _lobby._rooms.standing(_room.id)) {
        case RoomGone():
          unawaited(_end());
        case RoomAlive(:final expiresAt):
          _room = _room.copyWith(expiresAt: expiresAt);
          _watchExpiry();
      }
    } on LobbyException {
      // Сервер не ответил: проверка повторится по таймеру.
      _expiry?.cancel();
      _expiry = _lobby._scheduler.timer(_lobby.standingRetry, () => unawaited(_checkStanding()));
    } finally {
      _checking = false;
    }
  }

  /// Комнаты больше нет: новых гостей не будет, `NetworkGame` узнаёт об этом по закрытию потока соединений.
  Future<void> _end() async {
    if (_gone || _closed) return;
    _gone = true;
    _expiry?.cancel();
    unawaited(_connections.close());
    await _release(_channel);
  }

  Future<T> _serially<T>(Future<T> Function() operation) {
    final previous = _queue;
    final done = Completer<void>();
    _queue = done.future;
    return previous.then((_) => operation()).whenComplete(done.complete);
  }
}
