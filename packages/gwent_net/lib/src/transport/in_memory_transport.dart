import 'dart:async';
import 'dart:typed_data';

import 'package:gwent_net/src/transport/transport.dart';

/// Пара связанных транспортов в памяти: тесты протокола, игра на одном телефоне, бот и клиент хоста
/// (раздел 6.1 сетевой спецификации).
///
/// Кадры доставляются асинхронно и по порядку, как по сети; отправитель не делит буфер с получателем.
final class InMemoryTransport implements Transport {
  InMemoryTransport._(this._inbox);

  /// Два конца одного соединения.
  static (InMemoryTransport, InMemoryTransport) pair() {
    final a = InMemoryTransport._(StreamController<Uint8List>());
    final b = InMemoryTransport._(StreamController<Uint8List>());
    a._peer = b;
    b._peer = a;
    return (a, b);
  }

  final StreamController<Uint8List> _inbox;
  late final InMemoryTransport _peer;

  @override
  Stream<Uint8List> get incoming => _inbox.stream;

  @override
  void send(Uint8List frame) {
    if (!_peer._inbox.isClosed) _peer._inbox.add(Uint8List.fromList(frame));
  }

  @override
  Future<void> close() async {
    if (_inbox.isClosed) return;
    // Входящие закрываются без ожидания слушателя: соединение может закрыться до того, как его начали читать.
    unawaited(_inbox.close());
    unawaited(_peer._inbox.close());
  }
}
