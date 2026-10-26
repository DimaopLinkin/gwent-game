import 'dart:async';

import 'package:gwent/src/features/tutorial/domain/scenario_beat.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_move.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart' show MatchJournal, MatchRecord, RecordedMove;

/// Ведёт сценарий по звеньям (ADR 0034): знает, какое звено сейчас, пускает на стол только ход, который ждёт
/// сценарий, и переходит к следующему звену, когда движок принял ход или игрок нажал «Дальше».
///
/// Не знает ни экрана, ни стола: стол спрашивает [allows] перед ходом игрока и сообщает о принятом ходе через
/// [journal], бот ждёт своего звена в [untilBotBeat], а экран следит за [changes] и [nudges].
final class ScenarioDirector {
  /// Создаёт режиссёра над звеньями [beats].
  ScenarioDirector(List<Beat> beats) : beats = List.unmodifiable(beats);

  /// Звенья сценария по порядку.
  final List<Beat> beats;

  final StreamController<void> _changes = StreamController.broadcast();
  final StreamController<void> _nudges = StreamController.broadcast();
  Completer<void>? _botTurn;
  int _index = 0;
  bool _closed = false;

  /// Номер текущего звена; после последнего равен числу звеньев.
  int get index => _index;

  /// Текущее звено; `null`, когда сценарий закончен.
  Beat? get current => _index < beats.length ? beats[_index] : null;

  /// Сценарий пройден: принято последнее звено.
  bool get isCompleted => _index >= beats.length;

  /// Текущее звено сменилось.
  Stream<void> get changes => _changes.stream;

  /// Игрок сделал не то, чего ждёт сценарий: экран напоминает, что сейчас нужно.
  Stream<void> get nudges => _nudges.stream;

  /// Журнал партии для стола: каждое принятое движком намерение двигает сценарий дальше.
  MatchJournal get journal => _DirectorJournal(this);

  /// Игрок нажал «Дальше» на показе. Остальные звенья от нажатия не меняются.
  void acknowledge() {
    if (current is ShowBeat) _advance();
  }

  /// Можно ли пустить на стол намерение [intent] места [seat] при состоянии [state]: только ход игрока, которого ждёт
  /// сценарий. Иначе экран получает напоминание ([nudges]).
  bool allows(MatchState state, Seat seat, Intent intent) {
    final beat = current;
    final allowed = beat is PlayerBeat && seat == Seat.one && beat.move.matches(state, seat, intent);
    if (!allowed) _nudge();
    return allowed;
  }

  /// Напоминает экрану, что сейчас нужно другое: игрок тронул то, что не подсвечено.
  void nudge() => _nudge();

  /// Ход бота, который ждёт сценарий при состоянии [state]; ждёт, пока сценарий дойдёт до хода бота. `null`, если
  /// сценарий закончился или режиссёр закрыт.
  Future<Intent?> botIntent(MatchState state, Seat seat) async {
    while (!_closed) {
      final beat = current;
      if (beat == null) return null;
      if (beat is BotBeat) {
        return switch (beat.move) {
          final PlayMove move => move.toIntent(state, seat),
          PassMove() => const Pass(),
          LeaderMove() => const UseLeader(),
        };
      }
      final turn = _botTurn ??= Completer<void>();
      await turn.future;
    }
    return null;
  }

  /// Закрывает режиссёра: бот, который ждёт своего звена, отпускается.
  void close() {
    _closed = true;
    _botTurn?.complete();
    _botTurn = null;
    unawaited(_changes.close());
    unawaited(_nudges.close());
  }

  void _accepted(Seat seat) {
    final beat = current;
    final expected = switch (beat) {
      PlayerBeat() => Seat.one,
      BotBeat() => Seat.two,
      ShowBeat() || null => null,
    };
    // Стол принимает только то, что пропустил сценарий: другое намерение сюда не доходит.
    if (expected == seat) _advance();
  }

  void _advance() {
    _index++;
    if (!_changes.isClosed) _changes.add(null);
    if (current is BotBeat) {
      _botTurn?.complete();
      _botTurn = null;
    }
  }

  void _nudge() {
    if (!_nudges.isClosed) _nudges.add(null);
  }
}

/// Журнал, в который стол пишет принятые намерения: сообщает о них режиссёру. Партия «Первой партии» в историю и
/// реплеи не попадает, поэтому сам журнал ничего не хранит.
final class _DirectorJournal implements MatchJournal {
  const _DirectorJournal(this._director);

  final ScenarioDirector _director;

  @override
  void begin(MatchRecord record) {}

  @override
  void append(RecordedMove move) => _director._accepted(move.seat);
}
