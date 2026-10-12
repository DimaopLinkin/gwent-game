/// Кадр собеседника не удалось разобрать.
sealed class ProtocolException implements Exception {
  const ProtocolException(this.message);

  final String message;

  @override
  String toString() => 'ProtocolException: $message';
}

/// Кадр не соответствует протоколу: битый JSON, неизвестный тип, поле не того типа.
final class MalformedFrame extends ProtocolException {
  const MalformedFrame(super.message);
}

/// Кадр другой версии протокола; разобрать его нельзя, можно только ответить `reject`.
final class UnsupportedProtocol extends ProtocolException {
  const UnsupportedProtocol(this.version) : super('версия протокола $version не поддерживается');

  final int version;
}
