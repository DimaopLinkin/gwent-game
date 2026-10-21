import 'package:gwent/src/features/match/presentation/stage/stage_beat.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_frame.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

const double _never = double.infinity;
const double _always = double.negativeInfinity;

/// Жизнь одной карты в ряду на время сценария.
///
/// Карта занимает место с [reserveAt] до [removeAt] (соседи расступаются и смыкаются), а нарисована она только с
/// [showAt] до [hideAt]: пока она летит или горит в слое эффектов, на месте пусто.
@immutable
final class CardPhase {
  /// Создаёт жизнь карты.
  const CardPhase({
    required this.card,
    this.before,
    this.after,
    this.reserveAt = _always,
    this.showAt = _always,
    this.hideAt = _never,
    this.removeAt = _never,
    this.strengthAt = _always,
    this.fadeIn = 0,
  });

  /// Карта.
  final CardInstance card;

  /// Сила до сценария; `null`, если карты в ряду тогда не было.
  final int? before;

  /// Сила после сценария; `null`, если карты в ряду потом не будет.
  final int? after;

  /// С какого момента карта занимает место в ряду.
  final double reserveAt;

  /// С какого момента карта нарисована.
  final double showAt;

  /// С какого момента карта не нарисована (горит или переворачивается в слое эффектов).
  final double hideAt;

  /// С какого момента место карты свободно.
  final double removeAt;

  /// Когда показанная сила меняется с [before] на [after].
  final double strengthAt;

  /// Появление на месте за столько мс (режим «Уменьшить движение»); 0 — сразу.
  final double fadeIn;

  /// Карта занимает место на момент [time].
  bool occupies(double time) => time >= reserveAt && time < removeAt;

  /// Сила, которую показывает карта на момент [time].
  int strengthOn(double time) => (time >= strengthAt ? after ?? before : before ?? after) ?? 0;
}

/// Как меняется один ряд за сценарий: порядок карт и слот с погодой.
@immutable
final class RowSpec {
  /// Создаёт описание ряда.
  const RowSpec({
    required this.phases,
    required this.slotBefore,
    required this.slotAfter,
    required this.slotAt,
    required this.weatherBefore,
    required this.weatherAfter,
    required this.weatherAt,
  });

  /// Карты в порядке показа.
  final List<CardPhase> phases;

  /// Слот рога до сценария.
  final RowSlot? slotBefore;

  /// Слот рога после.
  final RowSlot? slotAfter;

  /// Когда слот меняется.
  final double slotAt;

  /// Была ли над рядом погода.
  final bool weatherBefore;

  /// Будет ли.
  final bool weatherAfter;

  /// Когда погода над рядом меняется.
  final double weatherAt;

  /// Ряд на момент [time].
  StagedRow at(double time) => StagedRow(
    cards: [
      for (final phase in phases)
        if (phase.occupies(time))
          StagedCard(
            view: FieldCardView(card: phase.card, strength: phase.strengthOn(time)),
            hidden: time < phase.showAt || time >= phase.hideAt,
            opacity: phase.fadeIn <= 0 || time >= phase.showAt + phase.fadeIn
                ? 1
                : ((time - phase.showAt) / phase.fadeIn).clamp(0.0, 1.0),
          ),
    ],
    slot: time >= slotAt ? slotAfter : slotBefore,
    weather: time >= weatherAt ? weatherAfter : weatherBefore,
  );
}

/// Звук в сценарии: [effect] начинается в момент [at] (мс от начала сценария).
@immutable
final class SoundCue {
  /// Создаёт звук сценария.
  const SoundCue({required this.at, required this.effect});

  /// Момент начала звука.
  final double at;

  /// Эффект.
  final SoundEffect effect;
}

/// Сценарий показа одного обновления партии: что и когда движется.
///
/// Сценарий не знает размеров экрана и не рисует: он собран из событий партии заранее, а в любой момент [frameAt]
/// отдаёт кадр, по которому поле и слой эффектов рисуют то, что должно быть видно. Поэтому тап «ускорить», пауза и
/// тесты работают одинаково: время — единственное, что бежит.
@immutable
final class StageScript {
  /// Создаёт сценарий.
  const StageScript({
    required this.id,
    required this.beats,
    required this.rows,
    required this.duration,
    this.veilEnds = 0,
    this.steps = const [],
    this.locks = const [],
    this.cues = const [],
    this.board,
  });

  /// Номер сценария: по нему поле отличает свой сценарий от следующего.
  final int id;

  /// Отрезки сценария.
  final List<StageBeat> beats;

  /// Ряды, которые сценарий меняет.
  final Map<RowRef, RowSpec> rows;

  /// Длительность, мс.
  final double duration;

  /// За сколько мс до конца с руки сходит вуаль: ввод разрешается, когда сценарий закончился.
  final double veilEnds;

  /// Моменты, с которых начинаются шаги сценария: кнопка «Пропустить» перескакивает к следующему. Пусто: пропускать
  /// нечего (розыгрыш карты короткий).
  final List<double> steps;

  /// Отрезки, внутри которых тап по полю не ускоряет показ: плашки итога читают на обычной скорости.
  final List<(double, double)> locks;

  /// Звуки сценария по времени: поле играет их, когда время сценария доходит до момента звука. Перескок кнопкой
  /// «Пропустить» пропущенные звуки не играет.
  final List<SoundCue> cues;

  /// Поле, на котором идёт сценарий, если оно не совпадает с тем, что держит экран партии: последний ход раунда
  /// показывают до подсчёта, а экран уже получил поле после уборки. `null` — поле экрана.
  final PlayerView? board;

  /// Можно ли ускорять показ тапом в момент [time].
  bool tapSpeedsUp(double time) => !locks.any((lock) => time >= lock.$1 && time < lock.$2);

  /// Начало следующего шага после [time]; конец сценария, если шагов больше нет.
  double nextStep(double time) {
    for (final step in steps) {
      if (step > time + 1) return step;
    }
    return duration;
  }

  /// Кадр на момент [time].
  StageFrame frameAt(double time) {
    final builder = StageFrameBuilder(time);
    for (final beat in beats) {
      beat.apply(builder);
    }
    return StageFrame(
      time: time,
      rows: {for (final entry in rows.entries) entry.key: entry.value.at(time)},
      counters: builder.counters,
      discardTops: builder.discardTops,
      flashes: builder.flashes,
      handHidden: builder.handHidden,
      leaderUsed: builder.leaderUsed,
      weatherSlots: builder.weatherSlots,
      gems: builder.gems,
      shakes: builder.shakes,
      handVeil: veilEnds <= 0 ? 1.0 : (1 - ((time - (duration - veilEnds)) / veilEnds)).clamp(0.0, 1.0),
      items: builder.items,
    );
  }
}
