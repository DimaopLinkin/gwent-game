import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/gwent_net.dart' as net show truncateUtf8;

/// Объявление партии в TXT-записи DNS-SD и обратно.
///
/// Ключи короткие: TXT-запись уходит в каждом ответе mDNS, а каждая пара ограничена 255 байтами.
/// Имя хоста обрезается по символам до [maxHostNameBytes] байт UTF-8. Чужие и битые записи не разбираются.
abstract final class GameAdRecord {
  /// Тип сервиса DNS-SD (раздел 6.2 спецификации). Тот же тип указан в `NSBonjourServices` iOS.
  static const String serviceType = '_gwent._tcp';

  /// Предел длины имени хоста в TXT-записи.
  static const int maxHostNameBytes = 63;

  static const String _game = 'g';
  static const String _hostName = 'n';
  static const String _protocol = 'v';
  static const String _rulesetId = 'ri';
  static const String _rulesetHash = 'rh';
  static const String _engineVersion = 're';
  static const String _open = 'o';

  /// TXT-запись объявления.
  static Map<String, String> encode(GameAd ad) => {
    _game: ad.id,
    _hostName: truncateUtf8(ad.hostName, maxHostNameBytes),
    _protocol: '${ad.protocol}',
    _rulesetId: ad.ruleset.id,
    _rulesetHash: ad.ruleset.hash,
    _engineVersion: '${ad.ruleset.engineVersion}',
    _open: ad.open ? '1' : '0',
  };

  /// Объявление из TXT-записи или `null`, если запись не наша или повреждена.
  static GameAd? decode(Map<String, String> attributes) {
    final id = attributes[_game];
    final hostName = attributes[_hostName];
    final protocol = int.tryParse(attributes[_protocol] ?? '');
    final rulesetId = attributes[_rulesetId];
    final rulesetHash = attributes[_rulesetHash];
    final engineVersion = int.tryParse(attributes[_engineVersion] ?? '');
    final open = switch (attributes[_open]) {
      '1' => true,
      '0' => false,
      _ => null,
    };
    if (id == null || id.isEmpty || hostName == null || protocol == null || rulesetId == null) return null;
    if (rulesetHash == null || engineVersion == null || open == null) return null;
    return GameAd(
      id: id,
      // Запись пришла из сети от кого угодно: имя очищается и обрезается по тем же правилам, что и при отправке.
      hostName: truncateUtf8(cleanDisplayName(hostName), maxHostNameBytes),
      ruleset: Ruleset(id: rulesetId, hash: rulesetHash, engineVersion: engineVersion),
      protocol: protocol,
      open: open,
    );
  }

  /// [text], обрезанный по целым символам так, чтобы в UTF-8 занимать не больше [maxBytes] байт.
  static String truncateUtf8(String text, int maxBytes) => net.truncateUtf8(text, maxBytes);
}
