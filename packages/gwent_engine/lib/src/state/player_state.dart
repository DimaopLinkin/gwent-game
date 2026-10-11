import 'package:gwent_engine/src/cards/faction.dart';
import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/row_state.dart';

/// Состояние одного игрока.
final class PlayerState extends Value {
  const PlayerState({
    required this.leader,
    required this.faction,
    required this.crystals,
    required this.deck,
    required this.hand,
    required this.discard,
    required this.rows,
    this.leaderUsed = false,
    this.leaderDisabled = false,
    this.passed = false,
    this.redrawsLeft = 0,
    this.redrawDone = false,
  });

  final LeaderId leader;

  /// Фракция колоды (фракция лидера).
  final Faction faction;

  /// Оставшиеся кристаллы (жизни).
  final int crystals;

  /// Колода; первый элемент — верхняя карта.
  final List<CardInstance> deck;
  final List<CardInstance> hand;

  /// Отбой в порядке поступления.
  final List<CardInstance> discard;
  final Map<Row, RowState> rows;

  /// Активная способность лидера уже применена в этой партии.
  final bool leaderUsed;

  /// Способность лидера отключена Белым Пламенем соперника.
  final bool leaderDisabled;
  final bool passed;

  /// Сколько карт ещё можно заменить при пересдаче.
  final int redrawsLeft;

  /// Игрок закончил пересдачу.
  final bool redrawDone;

  @override
  List<Object?> get props => [
    leader,
    faction,
    crystals,
    deck,
    hand,
    discard,
    rows,
    leaderUsed,
    leaderDisabled,
    passed,
    redrawsLeft,
    redrawDone,
  ];
}
