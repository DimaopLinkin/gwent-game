import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/animation.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/components/rolling_number.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_beat.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_frame.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_place.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_script.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent_engine/gwent_engine.dart';

part 'stage_builder_effects.dart';
part 'stage_builder_play.dart';
part 'stage_builder_scorch.dart';

const double _never = double.infinity;
const double _always = double.negativeInfinity;

/// События, которыми кончается розыгрыш одной карты: следующий ход, пас, начало раунда, выбор.
bool _endsScene(GameEvent event) =>
    event is CardPlayed ||
    event is TurnStarted ||
    event is Passed ||
    event is RoundStarted ||
    event is RoundEnded ||
    event is MatchEnded ||
    event is LeaderUsed ||
    event is ChoiceRequested;

/// События старта партии, перераздач и конца раунда: их показывают другие сцены (макеты 4, 5 и 13).
bool _isOutsideCardScenes(GameEvent event) =>
    event is RoundStarted ||
    event is RoundEnded ||
    event is MatchEnded ||
    event is DeckShuffled ||
    event is FirstPlayerChosen ||
    event is CardRedrawn ||
    event is RedrawFinished;

/// Жизнь карты в ряду, пока сценарий собирается.
final class _Draft {
  _Draft(this.card, {this.before, this.after});

  final CardInstance card;
  int? before;
  int? after;
  double reserveAt = _always;
  double showAt = _always;
  double hideAt = _never;
  double removeAt = _never;
  double strengthAt = _always;
  double fadeIn = 0;

  CardPhase freeze() => CardPhase(
    card: card,
    before: before,
    after: after,
    reserveAt: reserveAt,
    showAt: showAt,
    hideAt: hideAt,
    removeAt: removeAt,
    strengthAt: strengthAt,
    fadeIn: fadeIn,
  );
}

/// Ряд, пока сценарий собирается.
final class _RowDraft {
  _RowDraft({
    required this.order,
    required this.slotBefore,
    required this.slotAfter,
    required this.weatherBefore,
    required this.weatherAfter,
  });

  final List<_Draft> order;
  final RowSlot? slotBefore;
  final RowSlot? slotAfter;
  double slotAt = _always;
  final bool weatherBefore;
  final bool weatherAfter;
  double weatherAt = _always;

  bool get changed =>
      slotBefore != slotAfter ||
      weatherBefore != weatherAfter ||
      order.any(
        (draft) =>
            draft.before == null ||
            draft.after == null ||
            draft.before != draft.after ||
            draft.reserveAt != _always ||
            draft.hideAt != _never ||
            draft.removeAt != _never,
      );

  RowSpec freeze() => RowSpec(
    phases: [for (final draft in order) draft.freeze()],
    slotBefore: slotBefore,
    slotAfter: slotAfter,
    slotAt: slotAt,
    weatherBefore: weatherBefore,
    weatherAfter: weatherAfter,
    weatherAt: weatherAt,
  );
}

/// Собирает сценарий показа по двум проекциям партии и событиям между ними.
///
/// [prev] — что игрок видел до обновления, [next] — что видит после, [events] — что случилось между ними. Из событий
/// строятся сцены (розыгрыш карты, способности, Казнь, погода, лидер): каждая — цепочка отрезков во времени. Всё, что
/// сценарий не описал, поле покажет сразу по [next]: неполный сценарий ничего не ломает.
final class StageScriptBuilder {
  /// Создаёт сборщик; проекции должны быть одного игрока.
  StageScriptBuilder({
    required this.prev,
    required this.next,
    required this.catalog,
    this.style = StageStyle.normal,
  }) : viewer = next.viewer {
    _init();
  }

  /// Проекция до обновления.
  final PlayerView prev;

  /// Проекция после обновления.
  final PlayerView next;

  /// Справочник карт: по нему сцены отличают отряд от особой карты и героя от обычной карты.
  final CardCatalog catalog;

  /// Скорость и режим «Уменьшить движение».
  final StageStyle style;

  /// Игрок, чьими глазами смотрим.
  final Seat viewer;

  final List<StageBeat> _beats = [];
  final Map<RowRef, _RowDraft> _rows = {};
  final Map<CounterKey, int> _shadow = {};
  final Set<CounterKey> _started = {};
  final Map<bool, List<CardInstance>> _discards = {};
  final Set<bool> _topStarted = {};
  final Map<bool, bool> _leaderBefore = {};
  final Map<Row, bool> _slotsBefore = {};
  final Map<Row, bool> _slotsAfter = {};
  final Set<CardInstanceId> _discardHandled = {};
  double _cursor = 0;
  double? _settleAt;
  double _settleStagger = 0;
  bool _thought = false;

  bool get _rm => style.reduceMotion;

  double _ms(int token) => style.ms(token).toDouble();

  SideView _side(PlayerView view, {required bool mine}) => mine ? view.me : view.opponent;

  RowView? _rowView(PlayerView view, RowRef ref) => _side(view, mine: ref.mine).rows[ref.row];

  bool _mine(Seat seat) => seat == viewer;

  CounterKey _key(StageCounter kind, {required bool mine, Row? row}) => (kind: kind, mine: mine, row: row);

  void _init() {
    for (final mine in const [true, false]) {
      for (final row in Row.values) {
        final ref = (mine: mine, row: row);
        final before = _rowView(prev, ref);
        final after = _rowView(next, ref);
        _rows[ref] = _RowDraft(
          order: _mergeOrder(before?.cards ?? const [], after?.cards ?? const []),
          slotBefore: before?.slot,
          slotAfter: after?.slot,
          weatherBefore: before?.weather ?? false,
          weatherAfter: after?.weather ?? false,
        );
        _shadow[_key(StageCounter.rowScore, mine: mine, row: row)] = before?.strength ?? 0;
      }
      final before = _side(prev, mine: mine);
      _shadow[_key(StageCounter.total, mine: mine)] = before.score;
      _shadow[_key(StageCounter.hand, mine: mine)] = before.handCount;
      _shadow[_key(StageCounter.deck, mine: mine)] = before.deckCount;
      _shadow[_key(StageCounter.discard, mine: mine)] = before.discard.length;
      _discards[mine] = [...before.discard];
      _leaderBefore[mine] = before.leaderUsed;
    }
    for (final row in Row.values) {
      _slotsBefore[row] = _rowView(prev, (mine: true, row: row))?.weather ?? false;
      _slotsAfter[row] = _rowView(next, (mine: true, row: row))?.weather ?? false;
    }
  }

  /// Порядок карт в ряду: как в [after], а ушедшие встают после ближайшей предыдущей оставшейся карты.
  /// Пришедшие по умолчанию появляются сразу, ушедшие пропадают сразу: сцены уточняют время.
  List<_Draft> _mergeOrder(List<FieldCardView> before, List<FieldCardView> after) {
    final afterById = {for (final view in after) view.card.id: view};
    final beforeById = {for (final view in before) view.card.id: view};
    final order = <_Draft>[
      for (final view in after)
        _Draft(view.card, before: beforeById[view.card.id]?.strength, after: view.strength)
          ..reserveAt = beforeById.containsKey(view.card.id) ? _always : 0
          ..showAt = beforeById.containsKey(view.card.id) ? _always : 0,
    ];
    for (var i = 0; i < before.length; i++) {
      final view = before[i];
      if (afterById.containsKey(view.card.id)) continue;
      var at = 0;
      for (var j = i - 1; j >= 0; j--) {
        final position = order.indexWhere((draft) => draft.card.id == before[j].card.id);
        if (position >= 0) {
          at = position + 1;
          break;
        }
      }
      order.insert(at, _Draft(view.card, before: view.strength)..removeAt = 0);
    }
    return order;
  }

  /// Последняя жизнь карты в сценарии: у карты, ушедшей и вернувшейся, их две.
  _Draft? _draftOf(CardInstanceId id) {
    _Draft? found;
    for (final row in _rows.values) {
      for (final draft in row.order) {
        if (draft.card.id == id) found = draft;
      }
    }
    return found;
  }

  /// Жизнь, которая кончается: карту сжигают или уносят в руку.
  ///
  /// Если к концу сценария карта снова стоит в том же ряду (Казнь, потом Медик в обновлении с несколькими ходами),
  /// прежняя жизнь отделяется и встаёт перед ней, а возвращённая карта ждёт своего события. Одна жизнь на всё не
  /// годится: она не могла бы одновременно сгореть и снова занять место.
  _Draft _endLife(CardInstance card, RowRef ref) {
    final draft = _ensureDraft(card, ref);
    if (draft.before == null || draft.after == null) return draft;
    for (final row in _rows.values) {
      final index = row.order.indexOf(draft);
      if (index < 0) continue;
      final earlier = _Draft(card, before: draft.before)
        ..reserveAt = draft.reserveAt
        ..showAt = draft.showAt;
      row.order.insert(index, earlier);
      draft
        ..before = null
        ..reserveAt = _never
        ..showAt = _never;
      return earlier;
    }
    return draft;
  }

  /// Находит жизнь карты или заводит её в ряду [ref]: карта могла появиться и исчезнуть за один ход.
  _Draft _ensureDraft(CardInstance card, RowRef ref) {
    final draft = _draftOf(card.id);
    if (draft != null) return draft;
    final created = _Draft(card)
      ..reserveAt = 0
      ..showAt = 0
      ..removeAt = 0;
    _rows[ref]!.order.add(created);
    return created;
  }

  /// Число меняется с [at]: прокрутка, если оно отличается от того, что показывалось.
  void _count(CounterKey key, int to, double at, {double flash = 0}) {
    final from = _shadow[key] ?? 0;
    if (from == to) return;
    _beats.add(
      CounterBeat(
        key: key,
        from: from,
        to: to,
        at: at,
        roll: _rm ? 0 : _ms(StageTokens.roll),
        flash: flash,
        first: _started.add(key),
      ),
    );
    _shadow[key] = to;
  }

  void _bump(StageCounter kind, int delta, double at, {required bool mine}) {
    final key = _key(kind, mine: mine);
    _count(key, (_shadow[key] ?? 0) + delta, at);
  }

  void _topOfDiscard(bool mine, CardInstance? top, double at) {
    _beats.add(DiscardTopBeat(mine: mine, at: at, before: _prevTop(mine), after: top, first: _topStarted.add(mine)));
  }

  CardInstance? _prevTop(bool mine) => _side(prev, mine: mine).discard.lastOrNull;

  /// Карта [card] ложится в сброс игрока в момент [at]: растут счётчик и верх сброса.
  void _discardLands(CardInstance card, double at, {required bool mine}) {
    if (!_discardHandled.add(card.id)) return;
    final list = _discards[mine]!..add(card);
    _count(_key(StageCounter.discard, mine: mine), list.length, at);
    _topOfDiscard(mine, card, at);
  }

  /// Карта [card] уходит из сброса игрока в момент [at] (Медик, лидер).
  void _discardLeaves(CardInstance card, double at, {required bool mine}) {
    final list = _discards[mine]!;
    if (!list.any((c) => c.id == card.id)) return;
    list.removeWhere((c) => c.id == card.id);
    _count(_key(StageCounter.discard, mine: mine), list.length, at);
    _topOfDiscard(mine, list.lastOrNull, at);
  }

  /// Пересчёт сил карт и рядов: один раз, после последней сцены. [at] — момент прокрутки, [stagger] — шаг волны по
  /// картам слева направо.
  void _requestSettle(double at, {double stagger = 0}) {
    if (_settleAt == null || at >= _settleAt!) {
      _settleAt = at;
      _settleStagger = stagger;
    }
  }

  void _applySettle() {
    final at = _settleAt ?? _cursor;
    final flash = _ms(StageTokens.highlight);
    for (final entry in _rows.entries) {
      final ref = entry.key;
      final changing = entry.value.order.where((d) => d.before != null && d.after != null && d.before != d.after);
      // Волна по ряду не длиннее 600 мс, сколько бы карт ни менялось.
      final stagger = math.min(_settleStagger, _ms(600) / math.max(changing.length, 1));
      var step = 0;
      for (final draft in entry.value.order) {
        final before = draft.before;
        final after = draft.after;
        if (before == null || after == null || before == after) continue;
        draft.strengthAt = at + step * stagger;
        _beats.add(
          FlashBeat(
            card: draft.card.id,
            at: draft.strengthAt,
            duration: flash,
            tone: after > before ? RollTone.gain : RollTone.loss,
          ),
        );
        step++;
      }
      _count(
        _key(StageCounter.rowScore, mine: ref.mine, row: ref.row),
        _rowView(next, ref)?.strength ?? 0,
        at,
        flash: flash,
      );
    }
    for (final mine in const [true, false]) {
      _count(
        _key(StageCounter.total, mine: mine),
        _side(next, mine: mine).score,
        at,
        flash: flash,
      );
    }
  }

  /// Числа, которые сцены не довели до конечных значений, меняются в конце сценария.
  void _reconcile() {
    final at = _cursor;
    for (final mine in const [true, false]) {
      final after = _side(next, mine: mine);
      _count(_key(StageCounter.hand, mine: mine), after.handCount, at);
      _count(_key(StageCounter.deck, mine: mine), after.deckCount, at);
      _count(_key(StageCounter.discard, mine: mine), after.discard.length, at);
      final top = after.discard.lastOrNull;
      if (_discards[mine]!.lastOrNull != top) {
        _discards[mine] = [...after.discard];
        _topOfDiscard(mine, top, at);
      }
    }
  }

  /// Слоты погоды в центральной полосе: меняются в момент [at].
  void _slotsChange(double at) {
    for (final row in Row.values) {
      final before = _slotsBefore[row] ?? false;
      final after = _slotsAfter[row] ?? false;
      if (before != after) _beats.add(WeatherSlotBeat(row: row, at: at, before: before, after: after));
    }
  }

  /// Собирает сценарий [id] по событиям; `null`, если показывать нечего.
  StageScript? build(int id, List<GameEvent> events) {
    if (events.any(_isOutsideCardScenes)) return null;
    _walk(events);
    if (_beats.isEmpty) return null;
    _applySettle();
    _reconcile();
    for (final row in _rows.values) {
      for (final draft in row.order) {
        // Карта, которой к концу сценария быть в ряду, но ни одно событие её не вернуло: встаёт в конце.
        if (draft.after != null && draft.reserveAt == _never) draft.reserveAt = draft.showAt = _cursor;
      }
    }
    final rows = {
      for (final entry in _rows.entries)
        if (entry.value.changed) entry.key: entry.value.freeze(),
    };
    var end = _cursor;
    for (final beat in _beats) {
      end = math.max(end, beat.end);
    }
    for (final spec in rows.values) {
      for (final phase in spec.phases) {
        for (final time in [phase.showAt + phase.fadeIn, phase.removeAt, phase.strengthAt]) {
          if (time.isFinite) end = math.max(end, time);
        }
      }
    }
    // Вуаль на руке сходит за последние 180 мс сценария.
    final veil = _ms(StageTokens.fan);
    return StageScript(
      id: id,
      beats: List.unmodifiable(_beats),
      rows: rows,
      duration: end + veil,
      veilEnds: veil,
    );
  }

  /// События после [index] до конца этой сцены.
  List<(int, GameEvent)> _related(List<GameEvent> events, int index) {
    final related = <(int, GameEvent)>[];
    for (var i = index + 1; i < events.length; i++) {
      if (_endsScene(events[i])) break;
      related.add((i, events[i]));
    }
    return related;
  }

  void _walk(List<GameEvent> events) {
    final done = <int>{};
    for (var i = 0; i < events.length; i++) {
      if (done.contains(i)) continue;
      switch (events[i]) {
        case CardPlayed():
          _play(events, i, done);
        case LeaderUsed():
          _leader(events, i, done);
        case UnitPlaced(source: != EntrySource.hand):
          _standalone(events, i, done);
        case CardsDrawn() || CardsDrawnHidden():
          _standalone(events, i, done);
        default:
          break;
      }
    }
  }

  /// Пауза «соперник думает»: полоса соперника пульсирует. Один раз за сценарий и только в ходе соперника.
  double _think(double at) {
    if (_thought || _rm) {
      _thought = true;
      return at;
    }
    _thought = true;
    final pause = _ms(StageTokens.think);
    _beats.add(
      GlowBeat(
        place: const BarPlace(mine: false),
        color: const Color(0xFFC8A35B),
        start: at,
        end: at + pause,
        rise: at + _ms(80),
        fall: at + pause - _ms(60),
      ),
    );
    return at + pause;
  }
}
