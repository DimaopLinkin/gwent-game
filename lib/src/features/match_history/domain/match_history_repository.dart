import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';

/// История сыгранных партий.
abstract interface class MatchHistoryRepository {
  /// Все партии, сначала последние. Поток выдаёт новый список после каждой записи.
  Stream<List<MatchRecord>> watchAll();

  /// Партия с идентификатором [id] или `null`, если такой нет.
  Future<MatchRecord?> findById(String id);

  /// Добавляет партию в историю. С [replay] запись партии сохраняется вместе со сводкой, и `hasReplay` у записи
  /// истории верно; без него `hasReplay` ложно.
  Future<void> add(MatchRecord record, {ReplayLog? replay});

  /// Реплей партии [recordId] или `null`, если его нет. Бросает [ReplayCorrupted], если запись не читается.
  Future<ReplayLog?> findReplay(String recordId);
}

/// Запись реплея в хранилище не читается: она повреждена или записана неизвестным форматом.
final class ReplayCorrupted implements Exception {
  /// Создаёт ошибку с причиной [message].
  const ReplayCorrupted(this.message);

  /// Что не так.
  final String message;

  @override
  String toString() => 'ReplayCorrupted: $message';
}
