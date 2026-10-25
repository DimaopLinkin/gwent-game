import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;
import 'package:gwent_net/gwent_net.dart' show InMemoryMatchJournal;

/// Запись идущей партии: после её конца из неё получается реплей.
abstract interface class ReplayRecorder {
  /// Запись партии на сейчас; `null`, пока записывать нечего.
  ReplayLog? get log;
}

/// Запись местной партии по журналу в памяти: стол пишет в него каждый принятый ход.
final class JournalReplayRecorder implements ReplayRecorder {
  /// Создаёт запись над [journal] партии, которую смотрит место [perspective].
  const JournalReplayRecorder(this.journal, {required this.perspective});

  /// Журнал, в который стол дописывает ходы.
  final InMemoryMatchJournal journal;

  /// Чьими глазами партия записывается в историю.
  final Seat perspective;

  @override
  ReplayLog? get log => switch (journal.record) {
    final record? => JournalReplayLog(record, perspective: perspective),
    null => null,
  };
}
