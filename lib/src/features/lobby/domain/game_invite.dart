import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';

/// Приглашение в партию строкой (для QR-кода): запасной путь, когда сеть режет поиск (раздел 6.2 спецификации).
///
/// Формат в локальной сети: `gwent://lan/<идентификатор>?p=<порт>&h=<адрес>&h=<адрес>`, через интернет:
/// `gwent://online/<код комнаты>`.
abstract final class GameInvite {
  static const String _scheme = 'gwent';
  static const String _lan = 'lan';
  static const String _online = 'online';

  /// Строка приглашения по адресу.
  static String encode(GameAddress address) => switch (address) {
    LanAddress(:final gameId, :final hosts, :final port) => Uri(
      scheme: _scheme,
      host: _lan,
      pathSegments: [gameId],
      queryParameters: {'p': '$port', 'h': hosts},
    ).toString(),
    OnlineAddress(:final code) => Uri(scheme: _scheme, host: _online, pathSegments: [code.value]).toString(),
  };

  /// Адрес из строки приглашения или `null`, если строка не приглашение (чужой QR-код).
  static GameAddress? decode(String invite) {
    final uri = Uri.tryParse(invite.trim());
    if (uri == null || uri.scheme != _scheme || uri.pathSegments.length != 1) return null;
    final segment = uri.pathSegments.single;
    return switch (uri.host) {
      _lan => _decodeLan(uri, segment),
      _online => switch (RoomCode.tryParse(segment)) {
        final code? => OnlineAddress(code),
        null => null,
      },
      _ => null,
    };
  }

  static GameAddress? _decodeLan(Uri uri, String gameId) {
    final port = int.tryParse(uri.queryParameters['p'] ?? '');
    final hosts = uri.queryParametersAll['h'] ?? const [];
    if (gameId.isEmpty || port == null || port < 1 || port > 65535 || hosts.isEmpty) return null;
    return LanAddress(gameId: gameId, hosts: hosts, port: port);
  }
}
