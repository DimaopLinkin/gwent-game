import 'package:gwent/src/features/match_history/domain/match_record.dart';

/// История сыгранных партий.
abstract interface class MatchHistoryRepository {
  /// Все партии, сначала последние. Поток выдаёт новый список после каждой записи.
  Stream<List<MatchRecord>> watchAll();

  /// Добавляет партию в историю.
  Future<void> add(MatchRecord record);
}
