import 'dart:async';

import 'package:gwent/src/features/match/domain/awaited_action.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match/domain/seat_agent.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart' show MatchJournal, RecordedMove;

/// Партия целиком на этом устройстве: полное состояние живёт здесь, каждый ход проверяет и применяет движок.
///
/// Места с агентом ([SeatAgent], например бот) ходят сами, остальные — здешние, за них ходит человек через
/// [submit]. Без агентов это hot-seat: оба места здешние.
///
/// После каждого изменения партии стол спрашивает агентов, пока им есть что сделать. Если, пока агент думал,
/// партия изменилась (например, при пересдаче человек и бот действуют одновременно), его решение отбрасывается
/// и он решает заново по новому состоянию. Если агент ошибся (движок отклонил его ход, агент бросил исключение
/// или не ходит, когда партия ждёт его), приходит `TableFailed`.
///
/// Каждое принятое движком намерение стол дописывает в [journal] (если он есть): из журнала партия потом показывается
/// заново (реплей, ADR 0029). Начать журнал (`begin`) должен тот, кто создаёт стол, до первого хода.
final class LocalMatchTable implements MatchTable {
  /// Создаёт стол над партией, которую начал движок: [state] и события [startEvents] из `MatchEngine.start`.
  LocalMatchTable({
    required MatchEngine engine,
    required MatchState state,
    required List<GameEvent> startEvents,
    Map<Seat, SeatAgent> agents = const {},
    MatchJournal? journal,
  }) : _engine = engine,
       _state = state,
       _journal = journal,
       _agents = Map.unmodifiable(agents),
       localSeats = Set.unmodifiable({
         for (final seat in Seat.values)
           if (!agents.containsKey(seat)) seat,
       }) {
    if (localSeats.isEmpty) throw ArgumentError.value(agents, 'agents', 'Хотя бы за одно место должен ходить человек');
    _publish(startEvents);
    unawaited(_driveAgents());
  }

  final MatchEngine _engine;
  final Map<Seat, SeatAgent> _agents;
  final MatchJournal? _journal;
  final StreamController<TableUpdate> _updates = StreamController();
  MatchState _state;
  bool _driving = false;
  bool _closed = false;

  @override
  final Set<Seat> localSeats;

  /// Полное состояние партии сейчас: для журнала и тестов, экран его не видит.
  MatchState get state => _state;

  @override
  Stream<TableUpdate> get updates => _updates.stream;

  @override
  void submit(Seat seat, Intent intent) {
    if (_closed) throw StateError('Стол закрыт');
    if (!localSeats.contains(seat)) throw ArgumentError.value(seat, 'seat', 'За это место ходит не человек');
    switch (_engine.apply(_state, seat, intent)) {
      case Accepted(:final state, :final events):
        _accept(state, events, seat, intent);
        unawaited(_driveAgents());
      case Rejected(:final reject):
        _updates.add(IntentRefused(seat, intent, reject));
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    // Не ждём: без подписчика поток не завершится, а закрытие стола от этого не зависит.
    unawaited(_updates.close());
  }

  /// Спрашивает агентов по очереди, пока кто-то из них ходит. Одновременно работает один такой цикл.
  Future<void> _driveAgents() async {
    if (_driving || _agents.isEmpty) return;
    _driving = true;
    try {
      var moved = true;
      while (moved && !_closed) {
        moved = false;
        for (final MapEntry(key: seat, value: agent) in _agents.entries) {
          final before = _state;
          final intent = await agent.decide(before, seat);
          if (_closed) return;
          if (!identical(_state, before)) {
            // Партия изменилась, пока агент думал: его решение относится к старому состоянию.
            moved = true;
            break;
          }
          if (intent == null) continue;
          switch (_engine.apply(_state, seat, intent)) {
            case Accepted(:final state, :final events):
              _accept(state, events, seat, intent);
            case Rejected(:final reject):
              throw StateError('Движок отклонил намерение $intent за место ${seat.name}: ${reject.reason.name}');
          }
          moved = true;
          break;
        }
      }
      if (_closed) return;
      for (final seat in _agents.keys) {
        if (awaitsAction(_engine.project(_state, seat))) {
          // Иначе партия молча встала бы: человек ждёт хода, которого не будет.
          throw StateError('Агент места ${seat.name} не ходит, хотя партия ждёт его');
        }
      }
    } on Object catch (error) {
      if (!_closed) _updates.add(TableFailed(error));
    } finally {
      _driving = false;
    }
  }

  void _accept(MatchState state, List<GameEvent> events, Seat seat, Intent intent) {
    _state = state;
    _journal?.append(RecordedMove(seat, intent));
    _publish(events);
  }

  void _publish(List<GameEvent> events) => _updates.add(
    ViewsChanged(
      {for (final seat in localSeats) seat: _engine.project(_state, seat)},
      {for (final seat in localSeats) seat: _engine.eventsFor(events, seat)},
    ),
  );
}
