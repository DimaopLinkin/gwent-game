import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:gwent/src/features/lobby/data/online/room_message.dart';
import 'package:gwent_net/gwent_net.dart';

/// Соединение хоста с гостем поверх канала комнаты (ADR 0026): одно соединение — один [cid].
///
/// Кадр протокола уходит сообщением `frame` с номером соединения и стороной отправителя, закрытие — сообщением
/// `bye`. Тишина считается обрывом: так же, как в Wi-Fi, о живости связи судит протокол по `ping`. Транспорт
/// одноразовый: после обрыва гость подключается новым с другим [cid], а хост различает старое и новое соединение
/// по номеру.
final class RoomTransport implements Transport {
  /// Создаёт соединение [cid] стороны [side]. [send] отправляет сообщение в канал, [onClosed] вызывается один раз,
  /// когда соединение закрыто любой стороной.
  RoomTransport({
    required this.cid,
    required this.side,
    required void Function(RoomMessage message) send,
    void Function(RoomTransport transport)? onClosed,
  }) : _send = send,
       _onClosed = onClosed;

  /// Номер соединения.
  final int cid;

  /// Кто держит этот конец соединения.
  final RoomSide side;

  final void Function(RoomMessage message) _send;
  final void Function(RoomTransport transport)? _onClosed;
  final StreamController<Uint8List> _incoming = StreamController<Uint8List>();
  bool _closed = false;

  /// Соединение закрыто.
  bool get isClosed => _closed;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  void send(Uint8List frame) {
    if (_closed) return;
    final String data;
    try {
      data = utf8.decode(frame);
    } on FormatException {
      // Кодек протокола выдаёт UTF-8; всё остальное в канал не пустить: данные в нём строки.
      return;
    }
    _send(FrameMessage(cid: cid, from: side, data: data));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _send(ByeMessage(cid: cid, from: side));
    _finish();
  }

  /// Кадр собеседника по этому соединению.
  void receive(String data) {
    if (_closed) return;
    _incoming.add(Uint8List.fromList(utf8.encode(data)));
  }

  /// Собеседник закрыл соединение: отвечать ему не нужно.
  void peerClosed() => _finish();

  /// Канал больше недоступен: закрыть соединение молча, сказать собеседнику нечем.
  void abandon() => _finish();

  void _finish() {
    if (_closed) return;
    _closed = true;
    // Входящие закрываются без ожидания слушателя: соединение может оборваться до того, как его начали читать.
    unawaited(_incoming.close());
    _onClosed?.call(this);
  }
}
