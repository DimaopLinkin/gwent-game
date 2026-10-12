import 'package:gwent_net/src/journal/match_record.dart';

/// Куда хост пишет журнал партии. Реализация на диске появится вместе с восстановлением хоста.
abstract interface class MatchJournal {
  /// Партия началась: сид и колоды, ходов ещё нет.
  void begin(MatchRecord record);

  /// Движок принял намерение.
  void append(RecordedMove move);
}

/// Журнал в памяти: для тестов и партий, которые не нужно восстанавливать.
final class InMemoryMatchJournal implements MatchJournal {
  MatchRecord? _record;

  /// Журнал текущей партии; `null`, пока она не началась.
  MatchRecord? get record => _record;

  @override
  void begin(MatchRecord record) => _record = record;

  @override
  void append(RecordedMove move) {
    final record = _record;
    if (record == null) throw StateError('Ход до начала партии');
    _record = record.adding(move);
  }
}
