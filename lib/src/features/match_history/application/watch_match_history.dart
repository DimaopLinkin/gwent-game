import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';

/// Сценарий: следить за историей партий.
final class WatchMatchHistory {
  /// Создаёт сценарий над [repository].
  const WatchMatchHistory(this._repository);

  final MatchHistoryRepository _repository;

  /// Партии, сначала последние.
  Stream<List<MatchRecord>> call() => _repository.watchAll();
}
