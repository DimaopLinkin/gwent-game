import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Чем закончился раунд для игрока, который смотрит на экран.
enum RoundOutcome {
  /// Победа.
  win,

  /// Поражение.
  loss,

  /// Ничья: кристалл теряют оба.
  draw,
}

/// Что сработало у фракции в конце раунда (метка в блоке «Способности фракций»).
enum FactionMarkKind {
  /// Королевства Севера: победитель берёт карту.
  extraCard,

  /// Чудовища: одна карта остаётся на поле.
  unitStays,

  /// Нильфгаард: победа при ничьей по очкам.
  wonTie,
}

/// Метка сработавшей способности фракции.
@immutable
final class FactionMark {
  /// Создаёт метку.
  const FactionMark({required this.seat, required this.mine, required this.faction, required this.kind});

  /// Чья способность.
  final Seat seat;

  /// Способность игрока, который смотрит на экран.
  final bool mine;

  /// Фракция.
  final Faction faction;

  /// Что сработало.
  final FactionMarkKind kind;
}

/// Итог раунда для экрана между раундами (макет 5, раздел 2).
@immutable
final class RoundSummary {
  /// Создаёт итог.
  RoundSummary({
    required this.round,
    required this.mineSeat,
    required this.scoreMine,
    required this.scoreOpponent,
    required this.outcome,
    required this.crystalsMine,
    required this.crystalsOpponent,
    required this.mineFaction,
    required this.opponentFaction,
    required List<FactionMark> marks,
  }) : marks = List.unmodifiable(marks);

  /// Номер раунда.
  final int round;

  /// Место игрока, который смотрит на экран.
  final Seat mineSeat;

  /// Мой счёт.
  final int scoreMine;

  /// Счёт соперника.
  final int scoreOpponent;

  /// Итог для меня.
  final RoundOutcome outcome;

  /// Сколько кристаллов у меня осталось после раунда.
  final int crystalsMine;

  /// Сколько кристаллов осталось у соперника.
  final int crystalsOpponent;

  /// Моя фракция.
  final Faction mineFaction;

  /// Фракция соперника.
  final Faction opponentFaction;

  /// Сработавшие способности фракций.
  final List<FactionMark> marks;

  /// Я потерял кристалл в этом раунде.
  bool get lostMine => outcome != RoundOutcome.win;

  /// Соперник потерял кристалл в этом раунде.
  bool get lostOpponent => outcome != RoundOutcome.loss;
}
