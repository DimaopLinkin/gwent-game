import 'package:gwent_net/gwent_net.dart';
import 'package:meta/meta.dart';

/// Объявление партии, которое хост показывает соседям по сети (раздел 6 сетевой спецификации).
///
/// По объявлению гость решает, показывать ли партию в списке и можно ли к ней присоединиться, ещё до соединения.
/// Окончательно совместимость проверяет хост при рукопожатии (`hello`).
@immutable
final class GameAd {
  /// Создаёт объявление.
  const GameAd({
    required this.id,
    required this.hostName,
    required this.ruleset,
    this.protocol = protocolVersion,
    this.open = true,
  });

  /// Идентификатор объявленной партии: не меняется, пока хост её проводит, даже если хост объявляет её заново
  /// после сворачивания. По нему гость находит партию для переподключения. Это не `matchId` протокола.
  final String id;

  /// Имя игрока-хоста.
  final String hostName;

  /// Набор правил хоста.
  final Ruleset ruleset;

  /// Версия сетевого протокола хоста.
  final int protocol;

  /// Есть ли свободное место. После начала партии объявление остаётся для переподключения, но закрыто.
  final bool open;

  /// Почему новый игрок с набором правил [ruleset] не сможет присоединиться, или `null`, если сможет.
  ///
  /// Причины те же, что в отказе хоста, поэтому экран объясняет их одними словами.
  JoinRefusal? refusalFor(Ruleset ruleset) {
    if (protocol != protocolVersion) return JoinRefusal.protocolMismatch;
    if (this.ruleset != ruleset) return JoinRefusal.rulesetMismatch;
    if (!open) return JoinRefusal.matchFull;
    return null;
  }

  /// Копия с заменёнными полями.
  GameAd copyWith({String? hostName, bool? open}) => GameAd(
    id: id,
    hostName: hostName ?? this.hostName,
    ruleset: ruleset,
    protocol: protocol,
    open: open ?? this.open,
  );

  @override
  bool operator ==(Object other) =>
      other is GameAd &&
      other.id == id &&
      other.hostName == hostName &&
      other.ruleset == ruleset &&
      other.protocol == protocol &&
      other.open == open;

  @override
  int get hashCode => Object.hash(id, hostName, ruleset, protocol, open);

  @override
  String toString() => 'GameAd($id, $hostName, open: $open)';
}
