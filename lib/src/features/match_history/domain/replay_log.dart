import 'package:collection/collection.dart';
import 'package:gwent_engine/gwent_engine.dart' show GameEvent, Seat;
import 'package:gwent_net/gwent_net.dart' as net;
import 'package:meta/meta.dart';

/// Запись партии, из которой её можно показать заново (реплей).
///
/// Вид записи зависит от того, что видело устройство: у местной партии и хоста есть журнал ходов, из которого
/// движок строит партию целиком (обе руки видны), а у гостя сетевой партии журнала нет, и он хранит кадры своих
/// проекций, см. ADR 0029.
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

/// Кадры партии глазами игрока этого устройства: у гостя сетевой партии журнала нет, а руку и колоду соперника он
/// знать не должен, поэтому записывает то, что видел сам. Протокол от этого не меняется.
final class FramesReplayLog extends ReplayLog {
  /// Создаёт запись из кадров [frames], снятых при наборе правил [ruleset].
  FramesReplayLog(List<net.ViewFrame> frames, {required this.ruleset, required super.perspective})
    : frames = List.unmodifiable(frames);

  /// Кадры по порядку: проекция после каждого сообщения хоста и события, которые игрок увидел.
  final List<net.ViewFrame> frames;

  /// Набор правил партии: по нему видно, что карты, которые показывают кадры, остались теми же.
  final net.Ruleset ruleset;

  @override
  bool operator ==(Object other) =>
      other is FramesReplayLog &&
      other.perspective == perspective &&
      other.ruleset == ruleset &&
      const ListEquality<net.ViewFrame>(_FrameEquality()).equals(other.frames, frames);

  @override
  int get hashCode => Object.hash(perspective, ruleset, frames.length);
}

/// Сравнение кадров по содержимому: у записи с событиями-списком своё равенство не выходит.
final class _FrameEquality implements Equality<net.ViewFrame> {
  const _FrameEquality();

  @override
  bool equals(net.ViewFrame e1, net.ViewFrame e2) =>
      e1.view == e2.view && const ListEquality<GameEvent>().equals(e1.events, e2.events);

  @override
  int hash(net.ViewFrame e) => Object.hash(e.view, e.events.length);

  @override
  bool isValidKey(Object? o) => o is net.ViewFrame;
}
