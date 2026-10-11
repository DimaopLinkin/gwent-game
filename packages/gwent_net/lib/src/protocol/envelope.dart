import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/protocol/net_message.dart';

/// Конверт сообщения (раздел 3.1 сетевой спецификации).
///
/// [seq] — номер сообщения отправителя, с 1; у служебных сообщений 0. [ack] — номер последнего сообщения
/// собеседника, принятого без пропусков. Версия протокола добавляется при кодировании.
final class Envelope extends Value {
  const Envelope(this.message, {this.seq = 0, this.ack = 0, this.matchId});

  final NetMessage message;
  final int seq;
  final int ack;

  /// Партия; `null`, пока клиент её не знает (первый `hello`).
  final String? matchId;

  @override
  List<Object?> get props => [message, seq, ack, matchId];
}
