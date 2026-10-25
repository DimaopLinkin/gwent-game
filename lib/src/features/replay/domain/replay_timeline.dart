import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchRecord;
import 'package:gwent/src/features/match_history/domain/match_summary.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Состояние партии после одного хода (или после раздачи) глазами каждого места, которое реплей может показать.
@immutable
final class ReplayFrame {
  /// Создаёт кадр.
  ReplayFrame({required Map<Seat, PlayerView> views, required Map<Seat, List<GameEvent>> events})
    : views = Map.unmodifiable(views),
      events = Map.unmodifiable({
        for (final entry in events.entries) entry.key: List<GameEvent>.unmodifiable(entry.value),
      });

  /// Что видит каждое место.
  final Map<Seat, PlayerView> views;

  /// События, которые привели к этому кадру, для каждого места (скрытое от места не попадает).
  final Map<Seat, List<GameEvent>> events;
}

/// Шаг показа: поле, которое реплей выводит на экран, и события, которые к нему привели.
@immutable
final class ReplayStep {
  /// Создаёт шаг.
  ReplayStep({required this.frame, required this.view, required List<GameEvent> events, this.closing})
    : events = List.unmodifiable(events);

  /// Номер кадра шкалы, на котором стоит шаг.
  final int frame;

  /// Проекция после шага.
  final PlayerView view;

  /// События, которых зритель ещё не видел: с прошлого шага (включая кадры, пропущенные при показе).
  final List<GameEvent> events;

  /// Поле перед ходом, которым закончился раунд: по нему играют подсчёт и уборку карт; `null`, если раунд не кончился.
  final PlayerView? closing;

  /// Раунд, в котором стоит шаг.
  int get round => view.round;
}

/// Вся партия по кадрам: из неё реплей берёт шаги показа для любого из доступных мест.
@immutable
final class ReplayTimeline {
  /// Создаёт шкалу из кадров [frames]: нулевой кадр после раздачи, затем по кадру на ход.
  ///
  /// [seats] — места, чьими глазами партию можно смотреть, [perspective] — место игрока этого устройства.
  ReplayTimeline({required List<ReplayFrame> frames, required Set<Seat> seats, required this.perspective})
    : frames = List.unmodifiable(frames),
      seats = Set.unmodifiable(seats);

  /// Кадры по порядку.
  final List<ReplayFrame> frames;

  /// Места, чьими глазами можно смотреть партию.
  final Set<Seat> seats;

  /// Место игрока этого устройства: его глазами реплей открывается.
  final Seat perspective;

  /// Итог партии глазами [perspective] по последнему кадру или `null`, если партия не доиграна.
  MatchSummary? get summary {
    final view = frames.last.views[perspective];
    return view?.outcome == null ? null : MatchSummary.of(view!, perspective);
  }

  /// Сходится ли шкала со сводкой [record]: партия доиграна до того же итога и счёта.
  bool matches(MatchRecord record) {
    final summary = this.summary;
    return summary != null &&
        summary.outcome == record.outcome &&
        summary.roundsWon == record.roundsWon &&
        summary.roundsLost == record.roundsLost;
  }

  /// Шаги показа глазами [seat].
  ///
  /// Показываются кадры, в которых идёт партия или она окончена и никто не выбирает: пересдача, выбор первого игрока
  /// и выбор карт движком идут между ходами и в реплее не нужны, их события доходят до следующего шага.
  List<ReplayStep> stepsFor(Seat seat) {
    final steps = <ReplayStep>[];
    final unseen = <GameEvent>[];
    PlayerView? previous;
    for (final (index, frame) in frames.indexed) {
      final view = frame.views[seat]!;
      final events = frame.events[seat] ?? const <GameEvent>[];
      unseen.addAll(events);
      if (_isShown(view)) {
        steps.add(
          ReplayStep(
            frame: index,
            view: view,
            events: unseen,
            closing: events.any((event) => event is RoundEnded) ? previous : null,
          ),
        );
        unseen.clear();
      }
      previous = view;
    }
    return steps;
  }

  static bool _isShown(PlayerView view) =>
      (view.phase == MatchPhase.playing || view.phase == MatchPhase.finished) &&
      view.choice == null &&
      view.opponentChoosing == null;
}
