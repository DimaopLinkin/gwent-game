part of 'stage_builder.dart';

/// Ряды в порядке обхода при подсчёте: сначала соперника сверху вниз (осадный, дальний, ближний), затем мои.
final List<RowRef> _countOrder = [
  for (final row in Row.values.reversed) (mine: false, row: row),
  for (final row in Row.values) (mine: true, row: row),
];

/// Что уходит с поля в сброс в конце раунда и откуда.
typedef _Leaving = ({StagePlace from, CardInstance card, bool? ownerMine, _Draft? draft});

/// Конец раунда и матча (макет 13): подсчёт рядов, плашка итога, потеря камня, уход карт в сброс, способности фракций.
///
/// Времена в комментариях — в миллисекундах при обычной скорости.
extension _RoundScenes on StageScriptBuilder {
  void _roundEnd(List<GameEvent> events, int endIndex, RoundSummary summary) {
    final matchEnd = events.skip(endIndex).whereType<MatchEnded>().firstOrNull;
    final after = events.sublist(endIndex + 1).takeWhile((event) => event is! TurnStarted).toList();
    _steps
      ..add(0)
      ..add(_ms(300));
    final counted = _countRows(summary, from: _ms(300), until: _ms(matchEnd == null ? 1700 : 2500));
    _cursor = counted;
    if (matchEnd != null) {
      _matchEnd(matchEnd, at: counted);
      return;
    }
    final plaqueEnd = _plaque(summary, at: counted);
    _gems(summary, at: _ms(2400));
    final waveEnd = _discardWave(at: math.max(plaqueEnd + _ms(60), _ms(2960)));
    _cursor = math.max(_cursor, waveEnd);
    _factionEffects(after, waveEnd);
  }

  /// Шаг 2: ряды подсвечиваются по одному, в центральной полосе растёт счёт «мой : соперника».
  double _countRows(RoundSummary summary, {required double from, required double until}) {
    final step = _ms(60);
    final stepsAt = <double>[];
    final mine = <int>[];
    final theirs = <int>[];
    var mineSum = 0;
    var theirsSum = 0;
    for (final ref in _countOrder) {
      final view = _rowView(prev, ref);
      if (view == null || view.cards.isEmpty) continue;
      final at = from + stepsAt.length * step;
      stepsAt.add(at);
      if (ref.mine) {
        mineSum += view.strength;
      } else {
        theirsSum += view.strength;
      }
      mine.add(mineSum);
      theirs.add(theirsSum);
      _beats.add(
        GlowBeat(
          place: RowPlace(mine: ref.mine, row: ref.row),
          color: _gold,
          start: at,
          end: at + _ms(400),
          alpha: 0.4,
          kind: GlowKind.wash,
        ),
      );
    }
    if (stepsAt.isEmpty) {
      stepsAt.add(from);
      mine.add(0);
      theirs.add(0);
    }
    // Итог на плашке — счёт из события: он и есть то, что насчитал движок.
    mine[mine.length - 1] = summary.scoreMine;
    theirs[theirs.length - 1] = summary.scoreOpponent;
    final roll = _rm ? 0.0 : _ms(StageTokens.countRoll);
    _beats.add(
      CountBeat(
        start: from,
        end: until,
        stepsAt: stepsAt,
        mine: mine,
        theirs: theirs,
        roll: roll,
        winner: summary.outcome,
        winnerAt: stepsAt.last + roll,
        fade: _ms(StageTokens.fade),
      ),
    );
    return until;
  }

  /// Шаг 3: плашка итога раунда, под ней строки способностей фракций.
  double _plaque(RoundSummary summary, {required double at}) {
    final end = _ms(2900);
    final first = _ms(1950);
    // Строки способностей успевают появиться до ухода плашки, даже если их больше трёх.
    final gap = math.min(_ms(StageTokens.markGap), (end - _ms(250) - first) / math.max(1, summary.marks.length));
    _beats.add(
      PlaqueBeat(
        summary: summary,
        start: at,
        end: end,
        rise: _rm ? _ms(StageTokens.fade) : _ms(StageTokens.plaqueIn),
        markStarts: [for (var k = 0; k < summary.marks.length; k++) first + k * gap],
        fade: _ms(200),
        scales: !_rm,
      ),
    );
    _steps.add(at);
    _locks.add((at, end));
    return end;
  }

  /// Шаг 4: проигравший теряет камень жизни; при ничьей оба.
  void _gems(RoundSummary summary, {required double at}) {
    for (final mine in const [true, false]) {
      if (!(mine ? summary.lostMine : summary.lostOpponent)) continue;
      _beats.add(
        GemBeat(
          mine: mine,
          remaining: _side(next, mine: mine).crystals,
          start: at,
          duration: _ms(StageTokens.lifeTotal),
          shake: _ms(StageTokens.lifeShake),
          shakes: !_rm,
        ),
      );
    }
  }

  /// Шаг 5: карты поля волной уходят в сбросы владельцев, погода и рога гаснут, счёт обнуляется. Возвращает момент,
  /// когда всё в сбросе.
  double _discardWave({required double at}) {
    _steps.add(at);
    final leaving = _leaving();
    final flight = _ms(StageTokens.discardFlight);
    final gap = leaving.length <= 1
        ? 0.0
        : math.min(_ms(StageTokens.discardStep), (_ms(StageTokens.discardTotal) - flight) / (leaving.length - 1));
    final fade = _ms(StageTokens.fade);
    final waveEnd = _rm ? at + fade : at + (leaving.isEmpty ? 0 : gap * (leaving.length - 1) + flight);
    for (var k = 0; k < leaving.length; k++) {
      final item = leaving[k];
      final start = _rm ? at : at + k * gap;
      item.draft
        ?..hideAt = start
        ..removeAt = waveEnd;
      final owner = item.ownerMine;
      if (owner == null) continue;
      if (!_rm) {
        _beats.add(
          FlightBeat(
            ref: CardFaceRef(item.card, mine: owner),
            from: item.from,
            to: DiscardPlace(mine: owner),
            start: start,
            duration: flight,
            size: CardSize.row,
            shadowTo: 0,
            opacityTo: 0.6,
          ),
        );
      }
      _discardLands(item.card, _rm ? at + fade : start + flight, mine: owner);
    }
    _slotsChange(at);
    for (final row in _rows.values) {
      if (row.slotBefore != row.slotAfter) row.slotAt = at;
      if (row.weatherBefore != row.weatherAfter) row.weatherAt = at + _ms(StageTokens.fade);
    }
    _zeroCounters(at + _ms(150));
    return waveEnd;
  }

  /// Карты, которые к концу раунда уходят с поля, по порядку показа: отряды, затем рога и погода.
  List<_Leaving> _leaving() {
    bool onField(CardInstanceId id) => [next.me, next.opponent].any(
      (side) => side.rows.values.any((row) => row.cards.any((view) => view.card.id == id)),
    );
    bool? ownerOf(CardInstance card) => next.me.discard.any((c) => c.id == card.id)
        ? true
        : next.opponent.discard.any((c) => c.id == card.id)
        ? false
        : null;
    final leaving = <_Leaving>[];
    for (final ref in _countOrder) {
      for (final view in _rowView(prev, ref)?.cards ?? const <FieldCardView>[]) {
        if (onField(view.card.id)) continue;
        leaving.add((
          from: RowCardPlace(mine: ref.mine, row: ref.row, card: view.card.id),
          card: view.card,
          ownerMine: ownerOf(view.card),
          draft: _draftOf(view.card.id),
        ));
      }
    }
    for (final ref in _countOrder) {
      if (_rowView(prev, ref)?.slot case CardSlot(:final card)) {
        leaving.add((from: HornPlace(mine: ref.mine, row: ref.row), card: card, ownerMine: ownerOf(card), draft: null));
      }
    }
    for (final weather in prev.weather) {
      final row = switch (catalog.card(weather.card.cardId)) {
        SpecialCardDefinition(:final WeatherAbility ability) when ability.rows.isNotEmpty =>
          (ability.rows.toList()..sort((a, b) => a.index.compareTo(b.index))).first,
        _ => Row.melee,
      };
      leaving.add((
        from: WeatherSlotPlace(row),
        card: weather.card,
        ownerMine: _mine(weather.owner),
        draft: null,
      ));
    }
    return leaving;
  }

  /// Счёт рядов и общий счёт обнуляются, пока уходят карты: остаются только оставшиеся на поле.
  void _zeroCounters(double at) {
    for (final mine in const [true, false]) {
      final ids = {
        for (final row in Row.values)
          for (final view in _rowView(prev, (mine: mine, row: row))?.cards ?? const <FieldCardView>[]) view.card.id,
      };
      var total = 0;
      for (final row in Row.values) {
        final kept = (_rowView(next, (mine: mine, row: row))?.cards ?? const <FieldCardView>[]).where(
          (view) => ids.contains(view.card.id),
        );
        final sum = kept.fold<int>(0, (acc, view) => acc + view.strength);
        total += sum;
        _count(_key(StageCounter.rowScore, mine: mine, row: row), sum, at);
      }
      _count(_key(StageCounter.total, mine: mine), total, at);
    }
  }

  /// Способности фракций после ухода карт: Чудовища оставляют отряд, Скеллиге возвращает карты, Север берёт карту.
  void _factionEffects(List<GameEvent> after, double at) {
    for (final event in after) {
      if (event is UnitKept) {
        final place = RowCardPlace(mine: _mine(event.side), row: event.row, card: event.card.id);
        _beats.add(
          GlowBeat(
            place: place,
            color: _gold,
            start: at,
            end: at + _ms(StageTokens.keepPulse),
            rise: at + _ms(120),
            fall: at + _ms(260),
          ),
        );
        _cursor = math.max(_cursor, at + _ms(StageTokens.keepPulse));
      }
    }
    final returns = after.any((event) => event is UnitPlaced && event.source == EntrySource.perk);
    if (returns) {
      final hold = _ms(800);
      final fade = _ms(StageTokens.fade);
      _beats.add(
        CaptionBeat(kind: CaptionKind.perkReturn, start: at, rise: at + fade, fall: at + hold - fade, end: at + hold),
      );
      _cursor = math.max(_cursor, at + _ms(100));
    }
    _walk(after);
    // Приманка и Берсерк превращаются при уборке поля: новая карта встаёт на место после ухода остальных, а не с нуля.
    for (final event in after) {
      switch (event) {
        case CreatedCardPlaced():
          _cursor = math.max(_cursor, _created(event, at));
        case BerserkTransformed():
          _cursor = math.max(_cursor, _morph(event, at));
        default:
          break;
      }
    }
    _requestSettle(_cursor, stagger: _ms(70));
  }

  /// Сдача или выход соперника (макет 13): без подсчёта плашка исхода сразу, у сдавшегося гаснет камень.
  void _resignation(MatchEnded ended) {
    _steps.add(0);
    _matchEnd(ended, at: 0);
  }

  /// Конец матча: после подсчёта плашка исхода, проигравший теряет последний камень. При сдаче у проигравшего
  /// гаснет один из оставшихся камней: матч кончился не потерей камней, и пустого гнезда у него ещё нет.
  void _matchEnd(MatchEnded ended, {required double at}) {
    final winner = ended.outcome.winner;
    final outcome = switch (winner) {
      null => RoundOutcome.draw,
      _ when winner == viewer => RoundOutcome.win,
      _ => RoundOutcome.loss,
    };
    final end = at + _ms(1200);
    final wins = <Seat, int>{
      for (final seat in Seat.values) seat: next.history.where((result) => result.winner == seat).length,
    };
    _beats.add(
      MatchBannerBeat(
        outcome: outcome,
        roundsMine: wins[viewer] ?? 0,
        roundsTheirs: wins[viewer.opponent] ?? 0,
        winner: winner,
        start: at,
        end: end,
        rise: _rm ? _ms(StageTokens.fade) : _ms(StageTokens.plaqueIn),
        fade: _ms(200),
        scales: !_rm,
      ),
    );
    _steps.add(at);
    _locks.add((at, end));
    final resigned = ended.outcome.reason == MatchEndReason.resignation;
    for (final mine in const [true, false]) {
      final side = _side(next, mine: mine);
      final loses = winner != null && winner != (mine ? viewer : viewer.opponent);
      if (resigned ? !loses || side.crystals == 0 : side.crystals > 0) continue;
      _beats.add(
        GemBeat(
          mine: mine,
          remaining: resigned ? side.crystals - 1 : 0,
          start: at + _ms(300),
          duration: _ms(StageTokens.lifeTotal),
          shake: _ms(StageTokens.lifeShake),
          shakes: !_rm,
        ),
      );
    }
    _cursor = math.max(_cursor, end);
  }
}
