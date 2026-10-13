import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchMode;
import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Как играется местная партия.
enum LocalMatchMode {
  /// Два человека на одном телефоне передают его друг другу.
  hotSeat,

  /// Человек за первым местом против бота за вторым.
  vsBot,
}

/// Начатая партия: стол и то, что о ней нужно знать вне движка (для истории партий).
@immutable
final class MatchSession {
  /// Создаёт сессию.
  MatchSession({
    required this.mode,
    required this.table,
    required this.content,
    required Map<Seat, String> factionIds,
    Map<Seat, String> deckNames = const {},
  }) : factionIds = Map.unmodifiable(factionIds),
       deckNames = Map.unmodifiable(deckNames);

  /// Режим партии для истории: местные режимы и (позже) сетевые.
  final MatchMode mode;

  /// Стол, через который идёт партия.
  final MatchTable table;

  /// Контент партии: экран рисует карты по пакету, а правила движка берёт из справочника.
  final GameContent content;

  /// UUID фракции пакета контента у колоды каждого места.
  final Map<Seat, String> factionIds;

  /// Названия колод мест для экрана знакомства; места без названия (чужая колода по сети) в словаре нет.
  final Map<Seat, String> deckNames;

  /// Чьими глазами партия записывается в историю: первое здешнее место (в hot-seat это первый игрок).
  Seat get perspective => Seat.values.firstWhere(table.localSeats.contains);
}
