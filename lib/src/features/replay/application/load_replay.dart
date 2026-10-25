import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent/src/features/replay/application/build_journal_timeline.dart';
import 'package:gwent/src/features/replay/domain/replay_timeline.dart';
import 'package:gwent_content/gwent_content.dart' show ValidationIssue;
import 'package:gwent_engine/gwent_engine.dart' show GwentEngine, engineVersion;
import 'package:meta/meta.dart';

/// Итог загрузки реплея.
sealed class LoadReplayResult {
  const LoadReplayResult();
}

/// Реплей готов к показу.
final class ReplayLoaded extends LoadReplayResult {
  /// Создаёт итог.
  const ReplayLoaded(this.data);

  /// Что показывать.
  final ReplayData data;
}

/// Партии или её реплея нет (например, партия сыграна до реплеев).
final class ReplayMissing extends LoadReplayResult {
  /// Создаёт итог.
  const ReplayMissing();
}

/// Набор карт не прошёл проверку: партию построить нечем.
final class ReplayContentUnavailable extends LoadReplayResult {
  /// Создаёт итог.
  ReplayContentUnavailable(List<ValidationIssue> issues) : issues = List.unmodifiable(issues);

  /// Проблемы набора.
  final List<ValidationIssue> issues;
}

/// Почему реплей нельзя показать.
enum ReplayUnavailableReason {
  /// Набор карт или правила изменились после партии, и сохранённые ходы больше не дают той же партии.
  contentChanged,

  /// Запись повреждена или не от этого приложения.
  corrupted,
}

/// Реплей есть, но показать его нельзя.
final class ReplayUnavailable extends LoadReplayResult {
  /// Создаёт итог.
  const ReplayUnavailable(this.reason);

  /// Причина.
  final ReplayUnavailableReason reason;
}

/// Партия, готовая к показу.
@immutable
final class ReplayData {
  /// Создаёт данные реплея.
  const ReplayData({required this.record, required this.content, required this.timeline});

  /// Сводка партии из истории.
  final MatchRecord record;

  /// Набор карт, по которому партия показывается.
  final GameContent content;

  /// Партия по кадрам.
  final ReplayTimeline timeline;
}

/// Сценарий: загрузить реплей партии из истории и проверить, что он ещё показывает ту же партию.
///
/// Журнал проигрывается движком текущего набора карт. Если набор или версия движка изменились, это не повод отказать
/// сразу: ходы могут по-прежнему приниматься. Реплей открывается, только когда партия доиграна до того же итога и
/// счёта, что записаны в истории; иначе он недоступен (ADR 0029).
final class LoadReplay {
  /// Создаёт сценарий.
  const LoadReplay(this._history, this._content);

  final MatchHistoryRepository _history;
  final LoadGameContent _content;

  /// Загружает реплей партии [recordId].
  Future<LoadReplayResult> call(String recordId) async {
    final record = await _history.findById(recordId);
    if (record == null) return const ReplayMissing();
    final ReplayLog? log;
    try {
      log = await _history.findReplay(recordId);
    } on ReplayCorrupted {
      return const ReplayUnavailable(ReplayUnavailableReason.corrupted);
    }
    if (log == null) return const ReplayMissing();
    final GameContent content;
    switch (await _content()) {
      case GameContentReady(content: final ready):
        content = ready;
      case GameContentRejected(:final issues):
        return ReplayContentUnavailable(issues);
    }
    switch (log) {
      case JournalReplayLog(:final journal, :final perspective):
        final changed =
            journal.ruleset.hash != content.pack.manifest.contentHash || journal.ruleset.engineVersion != engineVersion;
        final failure = changed ? ReplayUnavailableReason.contentChanged : ReplayUnavailableReason.corrupted;
        final ReplayTimeline timeline;
        try {
          timeline = buildJournalTimeline(
            GwentEngine(content.catalog, rules: content.rules),
            journal,
            perspective: perspective,
          );
        } on Object {
          // Журнал не проигрывается (`JournalNotReplayable`) или движок на чужом наборе карт упал: он может упасть
          // любым исключением (карты, которой нет в справочнике, и т. п.). Для игрока это недоступный реплей.
          return ReplayUnavailable(failure);
        }
        if (!timeline.matches(record)) return ReplayUnavailable(failure);
        return ReplayLoaded(ReplayData(record: record, content: content, timeline: timeline));
      case FramesReplayLog(:final frames, :final ruleset, :final perspective):
        // Кадры готовые, движок не нужен; но карты на них показываются по текущему набору, и если набор другой,
        // сверить их нечем.
        if (ruleset.hash != content.pack.manifest.contentHash || ruleset.engineVersion != engineVersion) {
          return const ReplayUnavailable(ReplayUnavailableReason.contentChanged);
        }
        final timeline = ReplayTimeline(
          frames: [
            for (final frame in frames)
              ReplayFrame(views: {perspective: frame.view}, events: {perspective: frame.events}),
          ],
          seats: {perspective},
          perspective: perspective,
        );
        if (!timeline.matches(record)) return const ReplayUnavailable(ReplayUnavailableReason.corrupted);
        return ReplayLoaded(ReplayData(record: record, content: content, timeline: timeline));
    }
  }
}
