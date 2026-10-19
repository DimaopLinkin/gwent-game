import 'package:gwent_engine/gwent_engine.dart';

/// Игрок, который постучался в лобби и ждёт решения хоста (ADR 0022).
final class PendingGuest extends Value {
  const PendingGuest(this.seat, this.name);

  /// Место, которое игрок займёт, если хост согласится.
  final Seat seat;

  /// Имя из его `hello`, уже очищенное.
  final String name;

  @override
  List<Object?> get props => [seat, name];
}
