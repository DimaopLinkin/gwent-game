import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Сколько байт сокет может принять, пока приложение не получило ни одного целого сообщения.
///
/// Один счётчик на соединение: [WebSocketTransport] сбрасывает его с каждым принятым сообщением, а [CappedSocket]
/// прибавляет размер каждого куска из сети. Если куски копятся, а сообщений нет, значит, собеседник шлёт одно огромное
/// сообщение (или бесконечную цепочку обрывков): `dart:io` собрал бы его в памяти целиком, и телефон хоста закрыла
/// бы система.
final class ByteBudget {
  /// Создаёт счётчик с пределом [limit] байт.
  ByteBudget(this.limit);

  /// Предел байт без целого сообщения.
  final int limit;

  int _bytes = 0;

  /// Учитывает [bytes] из сети; `false`, если предел превышен.
  bool admit(int bytes) {
    _bytes += bytes;
    return _bytes <= limit;
  }

  /// Принято целое сообщение: счёт начинается заново.
  void messageReceived() => _bytes = 0;
}

/// Сокет, который обрывает соединение, когда собеседник превышает [ByteBudget].
///
/// `dart:io` не умеет ограничивать размер сообщения WebSocket, поэтому ограничение стоит ниже: между сетью и
/// разбором WebSocket. Всё остальное делегируется настоящему сокету.
final class CappedSocket extends StreamView<Uint8List> implements Socket {
  /// Оборачивает [socket].
  CappedSocket(Socket socket, ByteBudget budget) : this._(socket, _limited(socket, budget));

  CappedSocket._(this._socket, Stream<Uint8List> stream) : super(stream);

  final Socket _socket;

  /// Размер куска, который за один раз уходит на разбор WebSocket. Сокет может отдать за раз мегабайты (целую пачку
  /// сообщений), а счёт идёт по кускам: после каждого разбор успевает выдать целые сообщения и сбросить счётчик.
  /// Вдвое меньше предела, чтобы кусок вместе с хвостом предыдущего сообщения в предел укладывался.
  static const int _sliceBytes = 32 * 1024;

  static Stream<Uint8List> _limited(Socket socket, ByteBudget budget) async* {
    await for (final chunk in socket) {
      for (var start = 0; start < chunk.length; start += _sliceBytes) {
        final end = min(start + _sliceBytes, chunk.length);
        if (!budget.admit(end - start)) {
          // Лишнее не отдаём разбору WebSocket; соединение разрывается, поток входящих закроется сам.
          socket.destroy();
          return;
        }
        yield Uint8List.sublistView(chunk, start, end);
        // Пусть разбор выдаст целые сообщения (и сбросит счётчик) до следующего куска.
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  @override
  Encoding get encoding => _socket.encoding;

  @override
  set encoding(Encoding value) => _socket.encoding = value;

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _socket.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => _socket.addStream(stream);

  @override
  Future<void> close() => _socket.close();

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> flush() => _socket.flush();

  @override
  void write(Object? object) => _socket.write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) => _socket.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _socket.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => _socket.writeln(object);

  @override
  InternetAddress get address => _socket.address;

  @override
  InternetAddress get remoteAddress => _socket.remoteAddress;

  @override
  int get port => _socket.port;

  @override
  int get remotePort => _socket.remotePort;

  @override
  void destroy() => _socket.destroy();

  @override
  Uint8List getRawOption(RawSocketOption option) => _socket.getRawOption(option);

  @override
  void setRawOption(RawSocketOption option) => _socket.setRawOption(option);

  @override
  bool setOption(SocketOption option, bool enabled) => _socket.setOption(option, enabled);
}
