import 'package:gwent_engine/gwent_engine.dart' show Seat;
import 'package:gwent_net/gwent_net.dart' as net;
import 'package:meta/meta.dart';

/// Запись партии, из которой её можно показать заново (реплей).
///
/// Вид записи зависит от того, что видело устройство: у местной партии и хоста есть журнал ходов, из которого
/// движок строит партию целиком (обе руки видны), см. ADR 0029.
@immutable
sealed class ReplayLog {
  const ReplayLog({required this.perspective});

  /// Место игрока этого устройства: чьими глазами партия записана в историю.
  final Seat perspective;
}

/// Журнал ходов: сид, колоды и принятые движком намерения. Партию по нему заново строит движок.
final class JournalReplayLog extends ReplayLog {
  /// Создаёт запись над журналом [journal].
  const JournalReplayLog(this.journal, {required super.perspective});

  /// Журнал партии: набор правил, сид, колоды и ходы.
  final net.MatchRecord journal;

  @override
  bool operator ==(Object other) =>
      other is JournalReplayLog && other.perspective == perspective && other.journal == journal;

  @override
  int get hashCode => Object.hash(perspective, journal);
}
