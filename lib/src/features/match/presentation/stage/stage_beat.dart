import 'dart:math' as math;
import 'dart:ui' show Color, lerpDouble;

import 'package:flutter/animation.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/components/rolling_number.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_frame.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_place.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Доля от 0 до 1: где [time] между [from] и [to].
double _unit(double time, double from, double to) =>
    to <= from ? (time >= to ? 1.0 : 0.0) : ((time - from) / (to - from)).clamp(0.0, 1.0);

/// Трапеция: растёт между [a] и [b], держится до [c], гаснет к [d].
double window(double time, double a, double b, double c, double d) => _unit(time, a, b) * (1 - _unit(time, c, d));

/// Собирает кадр: предметы и числа складываются сюда, пока сценарий проходит по своим отрезкам.
final class StageFrameBuilder {
  /// Начинает кадр для момента [time].
  StageFrameBuilder(this.time);

  /// Момент сценария в миллисекундах.
  final double time;

  /// Прокручиваемые числа.
  final Map<CounterKey, RollValue> counters = {};

  /// Верхние карты сбросов.
  final Map<bool, CardInstance?> discardTops = {};

  /// Подсветка сил карт.
  final Map<CardInstanceId, CardFlash> flashes = {};

  /// Карты руки, которые ещё не долетели.
  final Set<CardInstanceId> handHidden = {};

  /// Лидеры, чья способность применена на этот момент.
  final Map<bool, bool> leaderUsed = {};

  /// Слоты погоды на этот момент.
  final Map<Row, bool> weatherSlots = {};

  final List<(int, StageItem)> _items = [];

  /// Добавляет эффект на слой [layer]; слои выше рисуются позже.
  void add(int layer, StageItem item) => _items.add((layer, item));

  /// Эффекты по слоям, порядок внутри слоя сохранён.
  List<StageItem> get items {
    final indexed = [for (var i = 0; i < _items.length; i++) (index: i, layer: _items[i].$1, item: _items[i].$2)];
    indexed.sort((a, b) => a.layer != b.layer ? a.layer.compareTo(b.layer) : a.index.compareTo(b.index));
    return [for (final entry in indexed) entry.item];
  }
}

/// Слои эффектов из макета 12: чем больше, тем выше.
abstract final class StageLayers {
  /// Слой погоды на рядах.
  static const int weather = 4;

  /// Подсветка рядов и слотов.
  static const int glow = 8;

  /// Затемнение поля.
  static const int scrim = 50;

  /// Пепел.
  static const int ash = 72;

  /// Карта в полёте.
  static const int flight = 60;

  /// Сгорающая цель Казни: выше затемнения.
  static const int target = 62;

  /// Подпись.
  static const int caption = 80;

  /// Карта, которую показывают крупно.
  static const int hold = 80;
}

/// Отрезок сценария: действует в своё время и добавляет своё в кадр.
@immutable
abstract class StageBeat {
  /// Создаёт отрезок.
  const StageBeat({required this.start, required this.end});

  /// Начало, мс.
  final double start;

  /// Конец, мс.
  final double end;

  /// Добавляет в [frame] то, что отрезок показывает в `frame.time`.
  void apply(StageFrameBuilder frame);
}

/// Карта летит от [from] к [to]. Длинный путь собирается из нескольких отрезков подряд.
final class FlightBeat extends StageBeat {
  /// Создаёт полёт длиной [duration] с началом [start].
  const FlightBeat({
    required this.ref,
    required this.from,
    required this.to,
    required super.start,
    required double duration,
    this.curve = StageTokens.out,
    this.arc = 0,
    this.scaleFrom = 1,
    this.scaleTo = 1,
    this.boost = 0,
    this.ryFrom = 0,
    this.ryTo = 0,
    this.ryCurve = StageTokens.inOut,
    this.shadowFrom = 1,
    this.shadowTo = 1,
    this.opacityFrom = 1,
    this.opacityTo = 1,
    this.size = CardSize.hand,
  }) : super(end: start + duration);

  /// Что нарисовано.
  final StageCardRef ref;

  /// Откуда.
  final StagePlace from;

  /// Куда.
  final StagePlace to;

  /// Кривая пути.
  final Curve curve;

  /// Высота дуги в pt: отрицательная поднимает вверх.
  final double arc;

  /// Множитель размера в начале и в конце.
  final double scaleFrom;

  /// См. [scaleFrom].
  final double scaleTo;

  /// Добавка к размеру в середине пути (0,12 — «вырастает на 12 %»).
  final double boost;

  /// Поворот вокруг вертикальной оси в начале и в конце, градусы.
  final double ryFrom;

  /// См. [ryFrom].
  final double ryTo;

  /// Кривая поворота.
  final Curve ryCurve;

  /// Тень в начале и в конце.
  final double shadowFrom;

  /// См. [shadowFrom].
  final double shadowTo;

  /// Непрозрачность в начале и в конце.
  final double opacityFrom;

  /// См. [opacityFrom].
  final double opacityTo;

  /// Размер, в котором нарисована карта.
  final CardSize size;

  @override
  void apply(StageFrameBuilder frame) {
    final time = frame.time;
    if (time < start || time >= end) return;
    final linear = _unit(time, start, end);
    final u = curve.transform(linear);
    frame.add(
      StageLayers.flight,
      CardFlightItem(
        ref: ref,
        from: from,
        to: to,
        u: u,
        arc: arc,
        scale: lerpDouble(scaleFrom, scaleTo, u)! + boost * math.sin(math.pi * linear),
        ry: lerpDouble(ryFrom, ryTo, ryCurve.transform(linear))!,
        shadow: lerpDouble(shadowFrom, shadowTo, u)!,
        size: size,
        opacity: lerpDouble(opacityFrom, opacityTo, linear)!,
      ),
    );
  }
}

/// Число прокручивается от [from] к [to] с момента [start].
final class CounterBeat extends StageBeat {
  /// Создаёт прокрутку; [roll] — длительность прокрутки (0 без прокрутки), [flash] — длительность подсветки.
  CounterBeat({
    required this.key,
    required this.from,
    required this.to,
    required double at,
    required this.roll,
    required this.flash,
    this.first = true,
  }) : super(start: at, end: at + math.max(roll, flash));

  /// Какое число.
  final CounterKey key;

  /// Было.
  final int from;

  /// Стало.
  final int to;

  /// Длительность прокрутки; 0 — число меняется сразу.
  final double roll;

  /// Длительность подсветки.
  final double flash;

  /// Первая прокрутка этого числа: до неё число показывает [from].
  final bool first;

  @override
  void apply(StageFrameBuilder frame) {
    final time = frame.time;
    if (time < start) {
      if (first) frame.counters[key] = RollValue(from, from, progress: 0);
      return;
    }
    final tone = to > from ? RollTone.gain : RollTone.loss;
    frame.counters[key] = RollValue(
      from,
      to,
      progress: roll <= 0 ? 1 : StageTokens.out.transform(_unit(time, start, start + roll)),
      flash: flash <= 0 ? 0 : window(time, start, start + 60, start + flash - 120, start + flash),
      tone: tone,
    );
  }
}

/// Верхняя карта сброса меняется в момент [start].
final class DiscardTopBeat extends StageBeat {
  /// Создаёт отрезок.
  const DiscardTopBeat({
    required this.mine,
    required double at,
    required this.before,
    required this.after,
    this.first = true,
  }) : super(start: at, end: at);

  /// Чей сброс.
  final bool mine;

  /// Верх сброса до момента.
  final CardInstance? before;

  /// Верх сброса после.
  final CardInstance? after;

  /// Первое изменение: до него показывается [before].
  final bool first;

  @override
  void apply(StageFrameBuilder frame) {
    if (frame.time >= start) {
      frame.discardTops[mine] = after;
    } else if (first) {
      frame.discardTops[mine] = before;
    }
  }
}

/// Затемнение поля: нарастает между [start] и [peakStart], держится до [peakEnd], гаснет к [end].
final class ScrimBeat extends StageBeat {
  /// Создаёт отрезок.
  const ScrimBeat({
    required super.start,
    required this.peakStart,
    required this.peakEnd,
    required super.end,
    this.alpha = 0.62,
  });

  /// Затемнение достигло полной силы.
  final double peakStart;

  /// Затемнение начинает гаснуть.
  final double peakEnd;

  /// Сила затемнения.
  final double alpha;

  @override
  void apply(StageFrameBuilder frame) {
    final value = alpha * window(frame.time, start, peakStart, peakEnd, end);
    if (value > 0) frame.add(StageLayers.scrim, ScrimItem(value));
  }
}

/// Подсветка места с огибающей: от [start] до [rise], держится до [fall], гаснет к [end].
final class GlowBeat extends StageBeat {
  /// Создаёт отрезок.
  const GlowBeat({
    required this.place,
    required this.color,
    required super.start,
    required super.end,
    double? rise,
    double? fall,
    this.alpha = 1,
    this.kind = GlowKind.frame,
    this.layer = StageLayers.glow,
    this.sweep = 0,
  }) : rise = rise ?? start + 80,
       fall = fall ?? end - 100;

  /// Что подсвечено.
  final StagePlace place;

  /// Цвет.
  final Color color;

  /// Достигает полной силы.
  final double rise;

  /// Начинает гаснуть.
  final double fall;

  /// Полная сила.
  final double alpha;

  /// Вид.
  final GlowKind kind;

  /// Слой.
  final int layer;

  /// Длительность роста заливки слева направо ([GlowKind.sweep]); 0 — вся сразу.
  final double sweep;

  @override
  void apply(StageFrameBuilder frame) {
    final value = alpha * window(frame.time, start, rise, fall, end);
    if (value <= 0) return;
    frame.add(
      layer,
      GlowItem(
        place: place,
        color: color,
        alpha: value,
        kind: kind,
        progress: sweep <= 0 ? 1 : StageTokens.inOut.transform(_unit(frame.time, start, start + sweep)),
      ),
    );
  }
}

/// Подпись рядом с картой.
final class CaptionBeat extends StageBeat {
  /// Создаёт отрезок.
  const CaptionBeat({
    required this.kind,
    required super.start,
    required double rise,
    required double fall,
    required super.end,
    this.card,
  }) : _rise = rise,
       _fall = fall;

  /// Какая подпись.
  final CaptionKind kind;

  /// Карта в подписи.
  final CardInstance? card;

  final double _rise;
  final double _fall;

  @override
  void apply(StageFrameBuilder frame) {
    final alpha = window(frame.time, start, _rise, _fall, end);
    if (alpha > 0) frame.add(StageLayers.caption, CaptionItem(kind: kind, card: card, alpha: alpha));
  }
}

/// Волна погоды по ряду.
final class WaveBeat extends StageBeat {
  /// Создаёт волну длиной [duration].
  const WaveBeat({
    required this.place,
    required super.start,
    required double duration,
    this.reverse = false,
    this.storm = false,
  }) : super(end: start + duration);

  /// Ряд.
  final RowPlace place;

  /// Выдох справа налево.
  final bool reverse;

  /// Шторм: молнии.
  final bool storm;

  @override
  void apply(StageFrameBuilder frame) {
    if (frame.time < start || frame.time >= end) return;
    frame.add(
      StageLayers.weather,
      WaveItem(
        place: place,
        progress: StageTokens.inOut.transform(_unit(frame.time, start, end)),
        reverse: reverse,
        storm: storm,
      ),
    );
  }
}

/// Цель Казни: рамка и подъём, затем сгорание.
final class BurnBeat extends StageBeat {
  /// Создаёт отрезок: цель выбирается с [start] за [target], горит с [burnStart] до [end].
  const BurnBeat({
    required this.place,
    required this.card,
    required super.start,
    required this.target,
    required this.burnStart,
    required super.end,
  });

  /// Где лежит карта.
  final RowCardPlace place;

  /// Карта.
  final CardInstance card;

  /// Длительность выбора цели.
  final double target;

  /// Начало сгорания.
  final double burnStart;

  @override
  void apply(StageFrameBuilder frame) {
    if (frame.time < start || frame.time >= end) return;
    frame.add(
      StageLayers.target,
      BurnItem(
        place: place,
        card: card,
        target: StageTokens.out.transform(_unit(frame.time, start, start + target)),
        burn: StageTokens.inOut.transform(_unit(frame.time, burnStart, end)),
      ),
    );
  }
}

/// Пепел от одной карты.
final class AshBeat extends StageBeat {
  /// Создаёт отрезок.
  const AshBeat({
    required this.place,
    required super.start,
    required double duration,
    required this.seed,
    this.count = 9,
  }) : super(end: start + duration);

  /// Где лежала карта.
  final RowCardPlace place;

  /// Зерно разлёта.
  final int seed;

  /// Сколько частиц.
  final int count;

  @override
  void apply(StageFrameBuilder frame) {
    if (frame.time < start || frame.time >= end) return;
    frame.add(
      StageLayers.ash,
      AshItem(place: place, progress: _unit(frame.time, start, end), seed: seed, count: count),
    );
  }
}

/// Берсерк превращается в медведя.
final class MorphBeat extends StageBeat {
  /// Создаёт отрезок длиной [duration].
  const MorphBeat({
    required this.place,
    required this.from,
    required this.to,
    required super.start,
    required double duration,
  }) : super(end: start + duration);

  /// Где лежит карта.
  final RowCardPlace place;

  /// Карта до превращения.
  final CardInstance from;

  /// Карта после.
  final CardInstance to;

  @override
  void apply(StageFrameBuilder frame) {
    if (frame.time < start || frame.time >= end) return;
    frame.add(
      StageLayers.flight,
      MorphItem(
        place: place,
        from: from,
        to: to,
        progress: StageTokens.inOut.transform(_unit(frame.time, start, end)),
      ),
    );
  }
}

/// Подсветка силы на карте в ряду.
final class FlashBeat extends StageBeat {
  /// Создаёт отрезок.
  const FlashBeat({required this.card, required double at, required double duration, required this.tone})
    : super(start: at, end: at + duration);

  /// Какая карта.
  final CardInstanceId card;

  /// Цвет.
  final RollTone tone;

  @override
  void apply(StageFrameBuilder frame) {
    final alpha = window(frame.time, start, start + 60, end - 120, end);
    if (alpha > 0) frame.flashes[card] = CardFlash(tone, alpha);
  }
}

/// Карта руки не показана, пока не долетит.
final class HandHideBeat extends StageBeat {
  /// Создаёт отрезок.
  const HandHideBeat({required this.card, required double until}) : super(start: 0, end: until);

  /// Какая карта.
  final CardInstanceId card;

  @override
  void apply(StageFrameBuilder frame) {
    if (frame.time < end) frame.handHidden.add(card);
  }
}

/// Мини-карта лидера гаснет в момент [start].
final class LeaderUsedBeat extends StageBeat {
  /// Создаёт отрезок.
  const LeaderUsedBeat({required this.mine, required double at, required this.before}) : super(start: at, end: at);

  /// Чей лидер.
  final bool mine;

  /// Была ли способность применена до сценария.
  final bool before;

  @override
  void apply(StageFrameBuilder frame) => frame.leaderUsed[mine] = frame.time >= start || before;
}

/// Слот погоды в центральной полосе загорается или гаснет в момент [start].
final class WeatherSlotBeat extends StageBeat {
  /// Создаёт отрезок.
  const WeatherSlotBeat({required this.row, required double at, required this.before, required this.after})
    : super(start: at, end: at);

  /// Какой слот.
  final Row row;

  /// Горел ли слот до момента.
  final bool before;

  /// Горит ли после.
  final bool after;

  @override
  void apply(StageFrameBuilder frame) => frame.weatherSlots[row] = frame.time >= start ? after : before;
}
