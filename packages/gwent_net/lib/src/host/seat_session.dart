import 'dart:async';

import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/protocol/net_message.dart';
import 'package:gwent_net/src/session/peer_link.dart';
import 'package:gwent_net/src/session/sequenced_channel.dart';

/// Место игрока у хоста: живёт всю партию, а соединения с ним приходят и уходят.
final class SeatSession {
  SeatSession({required this.seat, required this.token, required this.playerName, required String matchId})
    : channel = SequencedChannel(matchId: matchId);

  final Seat seat;

  /// Токен переподключения к этому месту.
  final String token;
  final String playerName;
  final SequencedChannel channel;

  /// Текущее соединение; `null`, пока игрок отключён.
  PeerLink? link;

  /// Клиент прислал что-то после `welcome`, значит, знает свой токен. Место без подтверждения
  /// (потерялся `welcome`) можно отдать новому клиенту, не дожидаясь тайм-аута.
  bool confirmed = false;

  /// Колода, принятая хостом до начала партии. Пока она есть, игрок готов.
  Deck? deck;

  /// Чем игрок занят в лобби, пока он не готов.
  LobbyStatus draft = const LobbyStatus(LobbyStage.choosing);

  /// Ожидание переподключения.
  Timer? grace;

  /// Хост только что переотправил игроку неподтверждённое: новые просьбы `resend` пропускаются до конца паузы.
  Timer? resendCooldown;

  /// Хост пустил игрока. До этого игрок видит только своё соединение: соперник о нём не знает.
  bool admitted = true;

  /// Время, за которое хост должен решить, пускать ли игрока.
  Timer? admission;

  /// Игрок давно не подавал признаков жизни, но обрыв ещё не засчитан.
  bool unstable = false;

  /// Игрок свернул приложение и ждёт возвращения партии.
  bool away = false;

  /// Игрок просит реванш или согласился на него.
  bool rematch = false;

  /// Какую фазу реванша игрок уже получил: повторно одно и то же ему не отправляется. `null` — ещё ничего.
  RematchPhase? rematchShown;

  bool get online => link != null;
}
