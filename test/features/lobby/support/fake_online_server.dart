import 'dart:async';

import 'package:gwent/src/features/lobby/data/online/online_rooms.dart';
import 'package:gwent/src/features/lobby/data/online/room_channel.dart';
import 'package:gwent/src/features/lobby/data/online/room_message.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';

import '../../../support/fakes.dart';

/// Комната на «сервере» тестов: те же правила, что в `supabase/migrations/` (ADR 0025).
final class FakeServerRoom {
  FakeServerRoom({
    required this.id,
    required this.code,
    required this.hostUid,
    required this.ad,
    required this.expiresAt,
  });

  final String id;
  final RoomCode code;
  final String hostUid;
  final GameAd ad;
  DateTime expiresAt;
  String? guestUid;
  bool open = true;
  DateTime? closedAt;

  /// Каналы, открытые в комнате.
  final List<FakeRoomChannel> channels = [];

  RoomInfo info() => RoomInfo(
    id: id,
    code: code,
    hostName: ad.hostName,
    protocol: ad.protocol,
    rulesetId: ad.ruleset.id,
    rulesetHash: ad.ruleset.hash,
    engineVersion: ad.ruleset.engineVersion,
    open: open,
    expiresAt: expiresAt,
  );
}

/// «Сервер» комнат в памяти: комнаты, лимиты и каналы. У каждого телефона свой вход ([phone]).
final class FakeOnlineServer {
  FakeOnlineServer(this.clock);

  final FakeClock clock;

  /// Комнаты по идентификатору, в том числе закрытые.
  final Map<String, FakeServerRoom> rooms = {};

  /// Неверные коды по игроку: восьмой подряд блокирует (как `join_failure` в базе).
  final Map<String, int> joinFailures = {};

  /// Сервис не отвечает всем телефонам.
  bool offline = false;

  int _created = 0;

  /// Комната по коду среди живых.
  FakeServerRoom? alive(String code) =>
      rooms.values.where((room) => isAlive(room) && room.code.value == code).firstOrNull;

  bool isAlive(FakeServerRoom room) => room.closedAt == null && room.expiresAt.isAfter(clock.now());

  /// Телефон игрока [uid].
  FakeOnlineRooms phone(String uid) => FakeOnlineRooms(this, uid);

  void _deliver(FakeServerRoom room, FakeRoomChannel from, RoomMessage message) {
    for (final channel in room.channels) {
      if (!identical(channel, from) && channel.up) channel._messages.add(message);
    }
  }

  RoomCode _nextCode() {
    var n = ++_created;
    final chars = StringBuffer();
    for (var i = 0; i < RoomCode.length; i++) {
      chars.write(RoomCode.alphabet[n % RoomCode.alphabet.length]);
      n ~/= RoomCode.alphabet.length;
    }
    return RoomCode.tryParse(chars.toString())!;
  }
}

/// Сервер комнат с точки зрения одного телефона.
final class FakeOnlineRooms implements OnlineRooms {
  FakeOnlineRooms(this._server, this.uid);

  final FakeOnlineServer _server;
  final String uid;

  /// Что телефон вызывал, по порядку: `create`, `join:КОД`, `setOpen:ID:open`, `close:ID`, `standing:ID`, `connect:ID`.
  final List<String> calls = [];

  /// Следующий вход в канал откажет.
  bool failConnect = false;

  /// Создание комнаты отказывает по правилам сервера, например `tooManyRooms`.
  LobbyFailure? createFailure;

  void _guard() {
    if (_server.offline) throw const LobbyException(LobbyFailure.unavailable, 'нет связи');
  }

  @override
  Future<RoomInfo> create(GameAd ad) async {
    calls.add('create');
    _guard();
    if (createFailure case final failure?) throw LobbyException(failure);
    for (final room in _server.rooms.values) {
      if (room.hostUid == uid && _server.isAlive(room)) {
        room
          ..open = false
          ..closedAt = _server.clock.now();
      }
    }
    final room = FakeServerRoom(
      id: 'room-${_server._created + 1}',
      code: _server._nextCode(),
      hostUid: uid,
      ad: ad,
      expiresAt: _server.clock.now().add(const Duration(minutes: 30)),
    );
    _server.rooms[room.id] = room;
    return room.info();
  }

  @override
  Future<RoomInfo> join(RoomCode code) async {
    calls.add('join:${code.value}');
    _guard();
    if ((_server.joinFailures[uid] ?? 0) >= 8) throw const LobbyException(LobbyFailure.tooManyAttempts);
    final room = _server.alive(code.value);
    if (room == null) {
      _server.joinFailures[uid] = (_server.joinFailures[uid] ?? 0) + 1;
      throw const LobbyException(LobbyFailure.codeNotFound);
    }
    if (room.hostUid == uid) throw const LobbyException(LobbyFailure.ownRoom);
    if (room.guestUid == uid) return room.info();
    if (room.guestUid != null) throw const LobbyException(LobbyFailure.roomFull);
    if (!room.open) throw const LobbyException(LobbyFailure.roomClosed);
    room
      ..guestUid = uid
      ..expiresAt = _server.clock.now().add(const Duration(hours: 6));
    return room.info();
  }

  @override
  Future<void> setOpen(String roomId, {required bool open}) async {
    calls.add('setOpen:$roomId:$open');
    _guard();
    final room = _hostRoom(roomId);
    room.open = open;
  }

  @override
  Future<void> close(String roomId) async {
    calls.add('close:$roomId');
    _guard();
    _hostRoom(roomId)
      ..open = false
      ..closedAt = _server.clock.now();
  }

  FakeServerRoom _hostRoom(String roomId) {
    final room = _server.rooms[roomId];
    if (room == null || room.hostUid != uid || !_server.isAlive(room)) {
      throw const LobbyException(LobbyFailure.codeNotFound);
    }
    return room;
  }

  @override
  Future<RoomStanding> standing(String roomId) async {
    calls.add('standing:$roomId');
    _guard();
    final room = _server.rooms[roomId];
    if (room == null || (room.hostUid != uid && room.guestUid != uid) || !_server.isAlive(room)) {
      return const RoomGone();
    }
    return RoomAlive(room.expiresAt);
  }

  @override
  Future<RoomChannel> connect(String roomId) async {
    calls.add('connect:$roomId');
    _guard();
    final room = _server.rooms[roomId];
    final allowed = room != null && (room.hostUid == uid || room.guestUid == uid) && _server.isAlive(room);
    if (failConnect || !allowed) {
      failConnect = false;
      throw const LobbyException(LobbyFailure.unavailable, 'доступ к каналу закрыт');
    }
    final channel = FakeRoomChannel(_server, room);
    room.channels.add(channel);
    return channel;
  }
}

/// Канал комнаты в памяти: сообщения идут другим каналам комнаты без своего эха, пока связь [up].
final class FakeRoomChannel implements RoomChannel {
  FakeRoomChannel(this._server, this._room);

  final FakeOnlineServer _server;
  final FakeServerRoom _room;
  final StreamController<RoomMessage> _messages = StreamController<RoomMessage>.broadcast();
  final StreamController<void> _trouble = StreamController<void>.broadcast();

  /// Связь есть: сообщения доходят в обе стороны. Без неё они теряются.
  bool up = true;

  /// Канал закрыт.
  bool closed = false;

  /// Все отправленные сообщения.
  final List<RoomMessage> sent = [];

  @override
  Stream<RoomMessage> get messages => _messages.stream;

  @override
  Stream<void> get trouble => _trouble.stream;

  @override
  void send(RoomMessage message) {
    if (closed) return;
    sent.add(message);
    if (up) _server._deliver(_room, this, message);
  }

  /// Канал сообщил о неполадке.
  void fail() => _trouble.add(null);

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    _room.channels.remove(this);
    await _messages.close();
    await _trouble.close();
  }
}
