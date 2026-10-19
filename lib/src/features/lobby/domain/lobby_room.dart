import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:meta/meta.dart';

/// Связь этого телефона с хостом партии.
enum RoomLink {
  /// Соединение устанавливается: хост ещё не выдал место.
  connecting,

  /// Хост на связи.
  online,

  /// Связь потеряна, телефон подключается заново.
  lost,
}

/// Соперник в комнате: кто он и что делает перед партией.
@immutable
final class RoomOpponent {
  /// Создаёт соперника.
  const RoomOpponent({required this.name, required this.online, this.stage = LobbyStage.choosing, this.leader});

  /// Имя из его `hello`.
  final String name;

  /// Соперник на связи; без связи его место держится, пока он не вернётся.
  final bool online;

  /// Чем он занят: выбирает колоду, собирает, выбрал или готов.
  final LobbyStage stage;

  /// Лидер его колоды; `null`, пока колода не выбрана. Колода соперника скрыта, видны только фракция и лидер.
  final LeaderId? leader;

  /// Копия с заменёнными полями.
  RoomOpponent copyWith({String? name, bool? online, LobbyStage? stage, LeaderId? leader, bool clearLeader = false}) =>
      RoomOpponent(
        name: name ?? this.name,
        online: online ?? this.online,
        stage: stage ?? this.stage,
        leader: clearLeader ? null : leader ?? this.leader,
      );

  @override
  bool operator ==(Object other) =>
      other is RoomOpponent &&
      other.name == name &&
      other.online == online &&
      other.stage == stage &&
      other.leader == leader;

  @override
  int get hashCode => Object.hash(name, online, stage, leader);

  @override
  String toString() => 'RoomOpponent($name, online: $online, ${stage.name})';
}

/// Почему игра в комнате закончилась, не начавшись.
@immutable
sealed class RoomEnd {
  const RoomEnd();
}

/// Хост не пустил: другая версия, другие данные карт, мест нет или токен не подошёл.
final class RoomRefused extends RoomEnd {
  /// Создаёт причину.
  const RoomRefused(this.reason);

  /// Ответ хоста.
  final JoinRefusal reason;

  @override
  bool operator ==(Object other) => other is RoomRefused && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

/// Хост закрыл лобби: возвращаться некуда.
final class RoomHostClosed extends RoomEnd {
  /// Создаёт причину.
  const RoomHostClosed();

  @override
  bool operator ==(Object other) => other is RoomHostClosed;

  @override
  int get hashCode => (RoomHostClosed).hashCode;
}

/// Связь потеряна, и вернуть её за отведённое время не удалось.
final class RoomConnectionLost extends RoomEnd {
  /// Создаёт причину.
  const RoomConnectionLost();

  @override
  bool operator ==(Object other) => other is RoomConnectionLost;

  @override
  int get hashCode => (RoomConnectionLost).hashCode;
}

/// Комната сетевой игры до начала партии: кто в ней, что делает каждый и идёт ли отсчёт.
@immutable
final class LobbyRoom {
  /// Создаёт состояние.
  const LobbyRoom({
    this.seat,
    this.link = RoomLink.connecting,
    this.opponent,
    this.myStage = LobbyStage.choosing,
    this.myLeader,
    this.countdown,
    this.started = false,
    this.deckRefused = false,
    this.end,
  });

  /// Место этого игрока; `null` до того, как хост его выдал.
  final Seat? seat;

  /// Связь с хостом.
  final RoomLink link;

  /// Соперник; `null`, пока никто не подключился или соперник ушёл.
  final RoomOpponent? opponent;

  /// Чем занят этот игрок.
  final LobbyStage myStage;

  /// Лидер выбранной колоды этого игрока.
  final LeaderId? myLeader;

  /// Оба готовы: партия начнётся через это время, если никто не отзовёт колоду. `null`, пока отсчёта нет.
  final Duration? countdown;

  /// Хост начал партию: комната закончилась, партию открывает `NetworkGame.openMatch`.
  final bool started;

  /// Хост не принял отправленную колоду; сбрасывается, когда игрок выбирает или отправляет колоду снова.
  final bool deckRefused;

  /// Почему комната закончилась без партии; `null`, пока она живёт.
  final RoomEnd? end;

  /// Копия с заменёнными полями. [clearOpponent], [clearCountdown] и [clearLeader] стирают соответствующие значения.
  LobbyRoom copyWith({
    Seat? seat,
    RoomLink? link,
    RoomOpponent? opponent,
    bool clearOpponent = false,
    LobbyStage? myStage,
    LeaderId? myLeader,
    bool clearLeader = false,
    Duration? countdown,
    bool clearCountdown = false,
    bool? started,
    bool? deckRefused,
    RoomEnd? end,
  }) => LobbyRoom(
    seat: seat ?? this.seat,
    link: link ?? this.link,
    opponent: clearOpponent ? null : opponent ?? this.opponent,
    myStage: myStage ?? this.myStage,
    myLeader: clearLeader ? null : myLeader ?? this.myLeader,
    countdown: clearCountdown ? null : countdown ?? this.countdown,
    started: started ?? this.started,
    deckRefused: deckRefused ?? this.deckRefused,
    end: end ?? this.end,
  );

  @override
  bool operator ==(Object other) =>
      other is LobbyRoom &&
      other.seat == seat &&
      other.link == link &&
      other.opponent == opponent &&
      other.myStage == myStage &&
      other.myLeader == myLeader &&
      other.countdown == countdown &&
      other.started == started &&
      other.deckRefused == deckRefused &&
      other.end == end;

  @override
  int get hashCode => Object.hash(seat, link, opponent, myStage, myLeader, countdown, started, deckRefused, end);

  @override
  String toString() => 'LobbyRoom(seat: $seat, $link, opponent: $opponent, ${myStage.name}, started: $started)';
}
