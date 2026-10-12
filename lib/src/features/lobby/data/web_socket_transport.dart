import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:gwent_net/gwent_net.dart';

/// Транспорт протокола поверх WebSocket (`dart:io`): Wi-Fi сейчас, сервер позже (раздел 6.2 спецификации).
///
/// Один кадр протокола — одно двоичное сообщение WebSocket, поэтому своё кадрирование длиной не нужно.
/// Текстовое сообщение не из протокола: соединение закрывается. Ошибка сокета, как и обрыв, просто закрывает
/// [incoming]; о живости связи судит протокол по `ping`.
final class WebSocketTransport implements Transport {
  /// Оборачивает открытый сокет.
  WebSocketTransport(this._socket) {
    _socket.listen(_onMessage, onError: _onError, onDone: _finish, cancelOnError: true);
    // Ошибка отправки повторяет ошибку потока входящих, которая уже закрыла соединение.
    _socket.done.ignore();
  }

  final WebSocket _socket;
  final StreamController<Uint8List> _incoming = StreamController<Uint8List>();
  bool _closed = false;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  void send(Uint8List frame) {
    if (_closed || _socket.readyState != WebSocket.open) return;
    _socket.add(frame);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _finish();
    // dart:io сам разрывает соединение, если собеседник не ответил на закрытие за несколько секунд.
    await _socket.close(WebSocketStatus.normalClosure);
  }

  void _onMessage(Object? message) {
    if (_closed) return;
    switch (message) {
      case final Uint8List frame:
        _incoming.add(frame);
      case final List<int> frame:
        _incoming.add(Uint8List.fromList(frame));
      default:
        unawaited(_closeAs(WebSocketStatus.unsupportedData));
    }
  }

  void _onError(Object error) => _finish();

  Future<void> _closeAs(int code) async {
    _finish();
    await _socket.close(code);
  }

  void _finish() {
    if (_closed) return;
    _closed = true;
    // Входящие закрываются без ожидания слушателя: соединение может оборваться до того, как его начали читать.
    unawaited(_incoming.close());
  }
}
