import 'dart:async';

import 'package:gwent_engine/gwent_engine.dart';
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

  /// Колода, принятая хостом до начала партии.
  Deck? deck;

  /// Ожидание переподключения.
  Timer? grace;

  bool get online => link != null;
}
