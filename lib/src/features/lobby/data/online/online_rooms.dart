import 'package:gwent/src/features/lobby/data/online/room_channel.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';
import 'package:meta/meta.dart';

/// Комната на сервере: то, что сервер сообщает о ней при создании и входе (ADR 0025, «Функции»).
@immutable
final class RoomInfo {
  /// Создаёт описание комнаты.
  const RoomInfo({
    required this.id,
    required this.code,
    required this.hostName,
    required this.protocol,
    required this.rulesetId,
    required this.rulesetHash,
    required this.engineVersion,
    required this.open,
    required this.expiresAt,
  });

  /// Идентификатор комнаты: по нему называется канал.
  final String id;

  /// Код, по которому в комнату входит гость.
  final RoomCode code;

  /// Имя хоста, как оно записано в комнате.
  final String hostName;

  /// Версия протокола хоста.
  final int protocol;

  /// Идентификатор пакета контента хоста.
  final String rulesetId;

  /// Хеш пакета контента хоста.
  final String rulesetHash;

  /// Версия движка хоста.
  final int engineVersion;

  /// Хост принимает нового гостя.
  final bool open;

  /// Когда комната закроется сама, если ничего не изменится (UTC).
  final DateTime expiresAt;

  /// Копия с заменёнными полями.
  RoomInfo copyWith({bool? open, DateTime? expiresAt}) => RoomInfo(
    id: id,
    code: code,
    hostName: hostName,
    protocol: protocol,
    rulesetId: rulesetId,
    rulesetHash: rulesetHash,
    engineVersion: engineVersion,
    open: open ?? this.open,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  @override
  bool operator ==(Object other) =>
      other is RoomInfo &&
      other.id == id &&
      other.code == code &&
      other.hostName == hostName &&
      other.protocol == protocol &&
      other.rulesetId == rulesetId &&
      other.rulesetHash == rulesetHash &&
      other.engineVersion == engineVersion &&
      other.open == open &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(id, code, hostName, protocol, rulesetId, rulesetHash, engineVersion, open, expiresAt);

  @override
  String toString() => 'RoomInfo($id, $code, open: $open)';
}

/// Жива ли комната на сервере.
@immutable
sealed class RoomStanding {
  const RoomStanding();
}

/// Комната жива и закроется сама не раньше [expiresAt] (UTC).
final class RoomAlive extends RoomStanding {
  /// Создаёт ответ.
  const RoomAlive(this.expiresAt);

  /// Когда комната закроется сама.
  final DateTime expiresAt;
}

/// Комнату закрыли, срок её жизни вышел или её удалили.
final class RoomGone extends RoomStanding {
  /// Создаёт ответ.
  const RoomGone();
}

/// Сервер комнат: создание комнаты, вход по коду и каналы (ADR 0025). Реализация — Supabase.
///
/// Все сбои приходят как `LobbyException`: отказ сервера по правилам (`codeNotFound`, `roomFull`, `tooManyAttempts` и
/// другие) и недоступность сервиса (`unavailable`: нет сети, проект уснул, анонимный вход отказал).
abstract interface class OnlineRooms {
  /// Создаёт комнату по объявлению хоста. Прежняя живая комната этого игрока закрывается сервером.
  Future<RoomInfo> create(GameAd ad);

  /// Занимает место гостя по [code]. Тот, кто уже гость этой комнаты, получает её снова.
  Future<RoomInfo> join(RoomCode code);

  /// Хост открывает или закрывает приём новых гостей.
  Future<void> setOpen(String roomId, {required bool open});

  /// Хост закрывает комнату; гость тоже теряет доступ.
  Future<void> close(String roomId);

  /// Хост подтверждает гостя: тот вошёл в канал и прислал кадр. Подтверждённое место гостя никому не отдаётся, пока
  /// комната жива (ADR 0028).
  Future<void> confirmGuest(String roomId);

  /// Жива ли комната. Видят её только участники.
  Future<RoomStanding> standing(String roomId);

  /// Входит в канал комнаты и возвращает его, когда вход подтверждён сервером.
  ///
  /// Бросает `LobbyException` с `unavailable`, если войти не удалось или сервер не ответил вовремя.
  Future<RoomChannel> connect(String roomId);
}
