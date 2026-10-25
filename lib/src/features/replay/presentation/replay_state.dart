import 'package:gwent/src/features/replay/application/load_replay.dart';
import 'package:gwent/src/features/replay/domain/replay_timeline.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;
import 'package:meta/meta.dart';

/// Скорость реплея: во сколько раз быстрее обычной идут анимации карт и паузы между ходами.
enum ReplaySpeed {
  /// Вдвое медленнее обычной.
  half(0.5),

  /// Обычная, как в партии.
  normal(1),

  /// Вдвое быстрее.
  fast(2),

  /// В четыре раза быстрее.
  fastest(4)
  ;

  const ReplaySpeed(this.factor);

  /// Во сколько раз быстрее обычной.
  final double factor;

  /// Доля обычных длительностей анимаций (`StageStyle.scale`).
  double get animationScale => 1 / factor;

  /// Следующая по кругу: 0.5 → 1 → 2 → 4 → 0.5.
  ReplaySpeed get next => values[(index + 1) % values.length];
}

/// Почему реплей не показывается.
enum ReplayFailure {
  /// Партии или её реплея нет.
  missing,

  /// Набор карт недоступен: партию построить нечем.
  contentUnavailable,

  /// Набор карт или правила изменились после партии.
  contentChanged,

  /// Запись повреждена.
  corrupted,
}

/// Состояние экрана реплея.
@immutable
sealed class ReplayState {
  const ReplayState();
}

/// Реплей загружается: журнал проигрывается движком.
final class ReplayLoading extends ReplayState {
  /// Создаёт состояние.
  const ReplayLoading();
}

/// Реплей показать нельзя.
final class ReplayFailed extends ReplayState {
  /// Создаёт состояние.
  const ReplayFailed(this.failure);

  /// Причина.
  final ReplayFailure failure;
}

/// Реплей идёт или стоит на шаге [index].
final class ReplayShowing extends ReplayState {
  /// Создаёт состояние.
  ReplayShowing({
    required this.data,
    required this.seat,
    required List<ReplayStep> steps,
    required this.index,
    required this.playing,
    required this.speed,
    required this.revision,
    required this.reset,
    required this.animate,
  }) : steps = List.unmodifiable(steps);

  /// Партия, которую показывает реплей.
  final ReplayData data;

  /// Чьими глазами смотрят партию.
  final Seat seat;

  /// Шаги показа глазами [seat].
  final List<ReplayStep> steps;

  /// Номер шага на поле.
  final int index;

  /// Реплей идёт сам.
  final bool playing;

  /// Скорость.
  final ReplaySpeed speed;

  /// Номер показа: растёт, когда на поле выходит другой шаг. По нему экран понимает, что поле нужно обновить.
  final int revision;

  /// Поле перед этим показом нужно сбросить: реплей перескочил, и прежние баннеры и сценарии не относятся к шагу.
  final bool reset;

  /// Показывать события шага анимациями; без этого поле просто встаёт в состояние шага.
  final bool animate;

  /// Шаг на поле.
  ReplayStep get step => steps[index];

  /// Реплей на первом шаге.
  bool get atStart => index == 0;

  /// Реплей на последнем шаге.
  bool get atEnd => index == steps.length - 1;

  /// Копия с заменёнными полями.
  ReplayShowing copyWith({
    Seat? seat,
    List<ReplayStep>? steps,
    int? index,
    bool? playing,
    ReplaySpeed? speed,
    int? revision,
    bool? reset,
    bool? animate,
  }) => ReplayShowing(
    data: data,
    seat: seat ?? this.seat,
    steps: steps ?? this.steps,
    index: index ?? this.index,
    playing: playing ?? this.playing,
    speed: speed ?? this.speed,
    revision: revision ?? this.revision,
    reset: reset ?? this.reset,
    animate: animate ?? this.animate,
  );
}
