import 'dart:async';

import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Партия по сети, как её видит этот телефон: одно здешнее место, ходы соперника приходят с хоста.
///
/// Стол не знает ни о сети, ни о протоколе: проекции и отказы ему подаёт сетевая игра ([updates]), намерения он
/// отдаёт ей же ([onSubmit]), а при закрытии просит её закрыться ([onClose]). Решение: ADR 0019.
final class NetworkMatchTable implements RematchTable {
  /// Создаёт стол за место [seat].
  NetworkMatchTable({
    required Seat seat,
    required Stream<TableUpdate> updates,
    required void Function(Intent intent) onSubmit,
    required Future<void> Function() onClose,
    required void Function() onRematch,
  }) : localSeats = Set.unmodifiable({seat}),
       _seat = seat,
       _updates = updates,
       _onSubmit = onSubmit,
       _onClose = onClose,
       _onRematch = onRematch;

  final Seat _seat;
  final Stream<TableUpdate> _updates;
  final void Function(Intent intent) _onSubmit;
  final Future<void> Function() _onClose;
  final void Function() _onRematch;
  bool _closed = false;

  @override
  final Set<Seat> localSeats;

  @override
  Stream<TableUpdate> get updates => _updates;

  @override
  void submit(Seat seat, Intent intent) {
    if (_closed) throw StateError('Стол закрыт');
    if (seat != _seat) throw ArgumentError.value(seat, 'seat', 'За это место ходит соперник');
    _onSubmit(intent);
  }

  @override
  void requestRematch() {
    if (!_closed) _onRematch();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _onClose();
  }
}
