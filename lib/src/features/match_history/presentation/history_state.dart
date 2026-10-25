import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:meta/meta.dart';

/// Фракция для подписи партии в истории: название и ключ (по нему подбирается цвет).
@immutable
final class HistoryFaction {
  /// Создаёт фракцию.
  const HistoryFaction({required this.key, required this.name});

  /// Ключ фракции в пакете контента.
  final String key;

  /// Название для игрока.
  final String name;
}

/// Состояние экрана истории партий.
@immutable
sealed class HistoryState {
  const HistoryState();
}

/// История читается.
final class HistoryLoading extends HistoryState {
  /// Создаёт состояние.
  const HistoryLoading();
}

/// История не читается.
final class HistoryFailed extends HistoryState {
  /// Создаёт состояние.
  const HistoryFailed(this.error);

  /// Причина.
  final Object error;
}

/// Партии прочитаны.
final class HistoryLoaded extends HistoryState {
  /// Создаёт состояние: [records] идут сначала последние, [factions] по UUID фракции; без набора карт он пуст.
  HistoryLoaded(List<MatchRecord> records, {Map<String, HistoryFaction> factions = const {}})
    : records = List.unmodifiable(records),
      factions = Map.unmodifiable(factions);

  /// Сыгранные партии.
  final List<MatchRecord> records;

  /// Названия фракций по UUID.
  final Map<String, HistoryFaction> factions;
}
