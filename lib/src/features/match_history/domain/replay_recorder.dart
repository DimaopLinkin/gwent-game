import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent_engine/gwent_engine.dart' show GameEvent, MatchPhase, PlayerView, Seat;
import 'package:gwent_net/gwent_net.dart' show InMemoryMatchJournal, Ruleset, ViewFrame;

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

/// Запись сетевой партии. Хост снимает журнал ходов в тот момент, когда партия кончилась (дальше реванш начнёт журнал
/// заново), гость собирает кадры своих проекций. Запись одной партии: для реванша нужна новая.
final class NetworkReplayRecorder implements ReplayRecorder {
  /// Создаёт запись партии, которую смотрит место [perspective]. Хост передаёт свой [journal].
  NetworkReplayRecorder({required this.perspective, required this.ruleset, InMemoryMatchJournal? journal})
    : _journal = journal;

  /// Чьими глазами партия записывается в историю.
  final Seat perspective;

  /// Набор правил партии.
  final Ruleset ruleset;

  final InMemoryMatchJournal? _journal;
  final List<ViewFrame> _frames = [];
  ReplayLog? _settled;

  /// Игрок увидел проекцию [view] и события [events]. В конце партии у хоста журнал уже полный.
  void add(PlayerView view, List<GameEvent> events) {
    if (_settled != null) return;
    // Журнал хоста всё хранит сам: кадры нужны только тому, у кого журнала нет.
    if (_journal == null && !_repeats(view, events)) _frames.add((view: view, events: List.unmodifiable(events)));
    if (view.phase != MatchPhase.finished) return;
    _settled = switch (_journal?.record) {
      final record? => JournalReplayLog(record, perspective: perspective),
      null => FramesReplayLog(_frames, ruleset: ruleset, perspective: perspective),
    };
  }

  /// Проекция после переподключения (снимок без событий) повторяет прежнюю и нового шага не даёт.
  bool _repeats(PlayerView view, List<GameEvent> events) =>
      events.isEmpty && _frames.isNotEmpty && _frames.last.view == view;

  @override
  ReplayLog? get log => _settled;
}
