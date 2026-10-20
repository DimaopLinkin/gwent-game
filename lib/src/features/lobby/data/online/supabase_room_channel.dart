import 'dart:async';

import 'package:gwent/src/features/lobby/data/online/room_channel.dart';
import 'package:gwent/src/features/lobby/data/online/room_message.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:supabase/supabase.dart';

/// Канал комнаты на Supabase Realtime Broadcast (ADR 0025, «Канал комнаты»).
///
/// Канал приватный (`private: true`): сервер пускает в него только хоста и гостя комнаты по политикам базы. Свои
/// сообщения канал не возвращает (`self: false`), подтверждений нет (`ack: false`).
final class SupabaseRoomChannel implements RoomChannel {
  SupabaseRoomChannel._(this._client, this._channel);

  /// Название канала комнаты [roomId].
  static String topic(String roomId) => 'room:$roomId';

  /// Входит в канал комнаты [roomId] и возвращает его, когда сервер подтвердил вход.
  ///
  /// Бросает [LobbyException] с `LobbyFailure.unavailable`, если сервер отказал во входе (комнату закрыли, нет
  /// доступа) или не ответил за [timeout]. Неудавшийся канал закрывается.
  static Future<SupabaseRoomChannel> join(
    SupabaseClient client,
    String roomId, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final channel = client.channel(
      topic(roomId),
      opts: const RealtimeChannelConfig(private: true),
    );
    final result = SupabaseRoomChannel._(client, channel);
    final joined = Completer<void>();
    for (final event in RoomMessage.events) {
      channel.onBroadcast(event: event, callback: (payload) => result._onBroadcast(event, payload));
    }
    channel.subscribe((status, error) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          if (!joined.isCompleted) joined.complete();
        case RealtimeSubscribeStatus.channelError || RealtimeSubscribeStatus.timedOut || RealtimeSubscribeStatus.closed:
          if (!joined.isCompleted) {
            joined.completeError(LobbyException(LobbyFailure.unavailable, error ?? status.name));
          } else if (!result._closed) {
            result._trouble.add(null);
          }
      }
    });
    try {
      await joined.future.timeout(timeout);
    } on LobbyException {
      await result.close();
      rethrow;
    } on TimeoutException catch (error) {
      await result.close();
      throw LobbyException(LobbyFailure.unavailable, error);
    }
    return result;
  }

  final SupabaseClient _client;
  final RealtimeChannel _channel;
  final StreamController<RoomMessage> _messages = StreamController<RoomMessage>.broadcast();
  final StreamController<void> _trouble = StreamController<void>.broadcast();
  bool _closed = false;

  @override
  Stream<RoomMessage> get messages => _messages.stream;

  @override
  Stream<void> get trouble => _trouble.stream;

  @override
  void send(RoomMessage message) {
    if (_closed) return;
    // Без связи сообщение теряется, а протокол партии его перешлёт; ответ о доставке не нужен.
    unawaited(_channel.sendBroadcastMessage(event: message.event, payload: message.payload));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _client.removeChannel(_channel);
    await _messages.close();
    await _trouble.close();
  }

  void _onBroadcast(String event, Map<String, dynamic> payload) {
    if (_closed) return;
    final message = RoomMessage.tryParse(event, payload);
    if (message != null) _messages.add(message);
  }
}
