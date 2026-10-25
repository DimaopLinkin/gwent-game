import 'package:meta/meta.dart';

/// Как шла партия.
enum MatchMode {
  /// Два игрока на одном телефоне.
  hotSeat,

  /// Два телефона в одной сети Wi-Fi.
  wifi,

  /// Два телефона по Bluetooth LE.
  bluetooth,

  /// Через сервер.
  server,

  /// Против ИИ.
  ai,
}

/// Итог партии для игрока этого устройства.
enum MatchOutcome {
  /// Победа.
  victory,

  /// Поражение.
  defeat,

  /// Ничья.
  draw,
}

/// Запись о сыгранной партии.
@immutable
final class MatchRecord {
  /// Создаёт запись.
  const MatchRecord({
    required this.id,
    required this.mode,
    required this.playerFactionId,
    required this.opponentFactionId,
    required this.opponentName,
    required this.outcome,
    required this.roundsWon,
    required this.roundsLost,
    required this.finishedAt,
    this.hasReplay = false,
  });

  /// Идентификатор записи.
  final String id;

  /// Как шла партия.
  final MatchMode mode;

  /// UUID фракции игрока.
  final String playerFactionId;

  /// UUID фракции соперника.
  final String opponentFactionId;

  /// Имя соперника, если оно известно (сетевая игра).
  final String? opponentName;

  /// Итог для игрока.
  final MatchOutcome outcome;

  /// Раунды, выигранные игроком.
  final int roundsWon;

  /// Раунды, выигранные соперником.
  final int roundsLost;

  /// Момент окончания партии (UTC).
  final DateTime finishedAt;

  /// У партии сохранён реплей; у партий, сыгранных до реплеев, и у сводок без записи его нет.
  final bool hasReplay;

  @override
  bool operator ==(Object other) =>
      other is MatchRecord &&
      other.id == id &&
      other.mode == mode &&
      other.playerFactionId == playerFactionId &&
      other.opponentFactionId == opponentFactionId &&
      other.opponentName == opponentName &&
      other.outcome == outcome &&
      other.roundsWon == roundsWon &&
      other.roundsLost == roundsLost &&
      other.finishedAt == finishedAt &&
      other.hasReplay == hasReplay;

  @override
  int get hashCode => Object.hash(
    id,
    mode,
    playerFactionId,
    opponentFactionId,
    opponentName,
    outcome,
    roundsWon,
    roundsLost,
    finishedAt,
    hasReplay,
  );

  @override
  String toString() => 'MatchRecord($id, ${mode.name}, ${outcome.name} $roundsWon:$roundsLost)';
}
