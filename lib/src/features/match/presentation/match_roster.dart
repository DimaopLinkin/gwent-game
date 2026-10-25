import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchMode;
import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Участник партии для экранов старта, итогов и полос игроков: чья сторона, какая фракция, лидер и колода.
@immutable
final class MatchPlayer {
  /// Создаёт участника.
  const MatchPlayer({required this.seat, required this.faction, required this.leader, this.deckName});

  /// Место за столом.
  final Seat seat;

  /// Фракция колоды.
  final Faction faction;

  /// Лидер колоды.
  final LeaderId leader;

  /// Название колоды; `null`, если оно неизвестно (чужая колода по сети).
  final String? deckName;

  @override
  bool operator ==(Object other) =>
      other is MatchPlayer &&
      other.seat == seat &&
      other.faction == faction &&
      other.leader == leader &&
      other.deckName == deckName;

  @override
  int get hashCode => Object.hash(seat, faction, leader, deckName);
}

/// Состав партии: режим и оба участника.
///
/// Нужен экранам, которые называют игроков и показывают их фракции и колоды; контент партии нужен, чтобы
/// нарисовать лидеров и назвать фракции. Профиля игрока нет: в hot-seat это «Игрок 1» и «Игрок 2», против бота «Вы» и
/// «Противник», по сети «Вы» и имя соперника из его `hello` (имя игрока в настройках), а если оно пустое, «Противник».
@immutable
final class MatchRoster {
  /// Создаёт состав.
  MatchRoster({
    required this.mode,
    required this.content,
    required Set<Seat> localSeats,
    required Map<Seat, MatchPlayer> players,
    String? opponentName,
  }) : opponentName = opponentName == null || opponentName.trim().isEmpty ? null : opponentName.trim(),
       localSeats = Set.unmodifiable(localSeats),
       players = Map.unmodifiable(players);

  /// Состав партии [session] по проекциям [views] её здешних мест (фракцию и лидера соперника видно из любой).
  factory MatchRoster.of(MatchSession session, Map<Seat, PlayerView> views) {
    final view = views.values.first;
    MatchPlayer player(Seat seat, SideView side) =>
        MatchPlayer(seat: seat, faction: side.faction, leader: side.leader, deckName: session.deckNames[seat]);
    return MatchRoster(
      mode: session.mode,
      content: session.content,
      localSeats: session.table.localSeats,
      opponentName: session.opponentName,
      players: {
        view.viewer: player(view.viewer, view.me),
        view.viewer.opponent: player(view.viewer.opponent, view.opponent),
      },
    );
  }

  /// Режим партии.
  final MatchMode mode;

  /// Контент партии.
  final GameContent content;

  /// Места, за которые ходят люди на этом устройстве.
  final Set<Seat> localSeats;

  /// Участники по местам.
  final Map<Seat, MatchPlayer> players;

  /// Имя соперника в сетевой партии; `null`, если он безымянный или партия местная.
  final String? opponentName;

  /// Два человека на одном телефоне: игроков зовут по номеру, а не «Вы» и «Противник».
  bool get hotSeat => localSeats.length > 1;

  /// Участник на месте [seat].
  MatchPlayer player(Seat seat) => players[seat]!;

  /// Это место за столом принадлежит человеку с этого устройства (в hot-seat — обоим).
  bool isLocal(Seat seat) => localSeats.contains(seat);

  /// Как зовут игрока на месте [seat].
  String name(Seat seat, AppLocalizations l10n) => hotSeat
      ? l10n.playerNumbered(seat.index + 1)
      : isLocal(seat)
      ? l10n.playerPlateYou
      : opponentName ?? l10n.matchPlayerOpponent;

  /// Оба участника — Скоя'таэли: первого игрока решает жребий, а не выбор.
  bool get bothScoiatael => players.values.every((player) => player.faction == Faction.scoiatael);

  @override
  bool operator ==(Object other) =>
      other is MatchRoster &&
      other.mode == mode &&
      other.opponentName == opponentName &&
      identical(other.content, content) &&
      other.localSeats.length == localSeats.length &&
      other.localSeats.containsAll(localSeats) &&
      other.players.length == players.length &&
      players.entries.every((entry) => other.players[entry.key] == entry.value);

  @override
  int get hashCode =>
      Object.hash(mode, opponentName, Object.hashAll(localSeats.map((seat) => seat.index)), players.length);
}
