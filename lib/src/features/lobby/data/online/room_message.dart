import 'package:meta/meta.dart';

/// Сторона комнаты: хост создал её, гость вошёл по коду.
enum RoomSide {
  /// Хост партии.
  host,

  /// Гость партии.
  guest,
}

/// Сообщение в канале комнаты (ADR 0025, 0026). Канал общий для хоста и гостя, поэтому у каждого сообщения есть
/// сторона отправителя [from], а соединение гостя с хостом называет [cid], выбранный гостем при каждом подключении.
@immutable
sealed class RoomMessage {
  const RoomMessage({required this.cid, required this.from});

  /// Предел длины кадра в символах: столько же, сколько предел сообщения WebSocket в Wi-Fi (ADR 0022).
  static const int maxFrameLength = 128 * 1024;

  /// Событие Broadcast, под которым идёт кадр протокола.
  static const String frameEvent = 'frame';

  /// Событие Broadcast, которым соединение закрывается.
  static const String byeEvent = 'bye';

  /// Все события, которые слушает канал.
  static const List<String> events = [frameEvent, byeEvent];

  /// Номер соединения: гость выбирает его случайно (32 бита) при каждом подключении.
  final int cid;

  /// Кто отправил сообщение.
  final RoomSide from;

  /// Имя события Broadcast.
  String get event;

  /// Нагрузка события.
  Map<String, Object?> get payload => {'cid': cid, 'from': from.name};

  /// Сообщение из события Broadcast или `null`, если нагрузка не по формату: чужое сообщение, подделка, сбой.
  ///
  /// Канал приватный, но писать в него может и гость, поэтому разбор ничему не доверяет: тип, диапазон и длина
  /// проверяются, остальное отбрасывается.
  static RoomMessage? tryParse(String event, Object? payload) {
    if (payload is! Map) return null;
    // Realtime отдаёт нагрузку либо сама по себе, либо внутри конверта `{event, payload, type}`.
    final body = payload['payload'] is Map ? payload['payload'] as Map : payload;
    final cid = body['cid'];
    final from = RoomSide.values.asNameMap()[body['from']];
    if (cid is! int || cid < 0 || cid >= 1 << 32 || from == null) return null;
    switch (event) {
      case frameEvent:
        final data = body['d'];
        if (data is! String || data.length > maxFrameLength) return null;
        return FrameMessage(cid: cid, from: from, data: data);
      case byeEvent:
        return ByeMessage(cid: cid, from: from);
    }
    return null;
  }
}

/// Кадр протокола `gwent_net` от одной стороны другой.
final class FrameMessage extends RoomMessage {
  /// Создаёт сообщение.
  const FrameMessage({required super.cid, required super.from, required this.data});

  /// Кадр: JSON в UTF-8, который выдаёт кодек протокола, как строка.
  final String data;

  @override
  String get event => RoomMessage.frameEvent;

  @override
  Map<String, Object?> get payload => {...super.payload, 'd': data};

  @override
  bool operator ==(Object other) =>
      other is FrameMessage && other.cid == cid && other.from == from && other.data == data;

  @override
  int get hashCode => Object.hash(cid, from, data);

  @override
  String toString() => 'FrameMessage($cid, ${from.name}, ${data.length} знаков)';
}

/// Соединение [cid] закрыто стороной [from].
final class ByeMessage extends RoomMessage {
  /// Создаёт сообщение.
  const ByeMessage({required super.cid, required super.from});

  @override
  String get event => RoomMessage.byeEvent;

  @override
  bool operator ==(Object other) => other is ByeMessage && other.cid == cid && other.from == from;

  @override
  int get hashCode => Object.hash(cid, from, 'bye');

  @override
  String toString() => 'ByeMessage($cid, ${from.name})';
}
