part of 'stage_builder.dart';

/// Казнь: карта крупно, затемнение, цели в красных рамках, сгорание, пепел и призраки в сброс.
extension _ScorchScenes on StageScriptBuilder {
  /// Особая карта Казнь.
  double _scorchCard(CardPlayed played, List<(int, GameEvent)> related, Set<int> done, double at) {
    final mineSeat = _mine(played.seat);
    _bump(StageCounter.hand, -1, at, mine: mineSeat);
    final hasTargets = related.any((entry) => entry.$2 is UnitsDestroyed);
    final holdEnd = _showCentered(
      played.card,
      mine: mineSeat,
      at: at,
      hold: _ms(StageTokens.holdScorch),
      caption: !mineSeat && hasTargets,
    );
    final fly = _ms(StageTokens.flightShort);
    final landed = _rm ? holdEnd : holdEnd + fly;
    if (!_rm) {
      _beats.add(
        FlightBeat(
          ref: CardFaceRef(played.card, mine: mineSeat),
          from: const CenterPlace(),
          to: DiscardPlace(mine: mineSeat),
          start: holdEnd,
          duration: fly,
          arc: -20,
          shadowTo: 0,
          size: CardSize.grid,
          scaleTo: 0.3,
        ),
      );
    }
    _discardLands(played.card, landed, mine: mineSeat);
    if (!hasTargets) {
      _beats.add(
        CaptionBeat(
          kind: CaptionKind.noTargets,
          start: holdEnd - _ms(StageTokens.hold),
          rise: holdEnd - _ms(StageTokens.hold) + _ms(StageTokens.fade),
          fall: landed,
          end: landed + _ms(StageTokens.fade),
        ),
      );
      return landed + _ms(StageTokens.fade);
    }
    return _scorchResolve(related, done, holdEnd);
  }

  /// Цели Казни: затемнение, рамки, сгорание. Возвращает момент, когда всё закончилось.
  double _scorchResolve(List<(int, GameEvent)> related, Set<int> done, double at) {
    final destroyed = related.where((entry) => !done.contains(entry.$1) && entry.$2 is UnitsDestroyed).firstOrNull;
    if (destroyed == null) return at;
    done.add(destroyed.$1);
    final units = (destroyed.$2 as UnitsDestroyed).units;
    var end = at;
    var freeAt = at;
    var discardAt = at;
    if (_rm) {
      for (final unit in units) {
        _endLife(unit.card, (mine: _mine(unit.side), row: unit.row)).removeAt = at;
        if (!_isCreated(unit.card)) _discardLands(unit.card, at + _ms(StageTokens.fade), mine: _mine(unit.side));
        _beats.add(
          GlowBeat(
            place: RowPlace(mine: _mine(unit.side), row: unit.row),
            color: const Color(0xFFD94A3A),
            start: at,
            end: at + _ms(StageTokens.fade) * 2,
            alpha: 0.3,
            kind: GlowKind.wash,
          ),
        );
      }
      end = at + _ms(StageTokens.fade);
      freeAt = at;
      discardAt = at + _ms(StageTokens.fade);
    } else {
      final target = _ms(StageTokens.target);
      final burn = _ms(StageTokens.burn);
      final ash = _ms(600);
      final ghost = _ms(StageTokens.flightShort);
      final burnStart = at + target;
      final burnEnd = burnStart + burn;
      _beats.add(
        ScrimBeat(
          start: at,
          peakStart: at + target,
          peakEnd: burnEnd,
          end: burnEnd + _ms(StageTokens.fade),
        ),
      );
      for (final unit in units) {
        final mine = _mine(unit.side);
        final place = RowCardPlace(mine: mine, row: unit.row, card: unit.card.id);
        _endLife(unit.card, (mine: mine, row: unit.row))
          ..hideAt = at
          ..removeAt = burnEnd;
        _beats
          ..add(
            BurnBeat(place: place, card: unit.card, start: at, target: target, burnStart: burnStart, end: burnEnd),
          )
          ..add(AshBeat(place: place, start: burnStart + burn * 0.4, duration: ash, seed: unit.card.id.value));
        if (!_isCreated(unit.card)) {
          _beats.add(
            FlightBeat(
              ref: CardFaceRef(unit.card, mine: mine),
              from: place,
              to: DiscardPlace(mine: mine),
              start: burnEnd,
              duration: ghost,
              size: CardSize.row,
              opacityFrom: 0.5,
              opacityTo: 0,
              shadowTo: 0,
            ),
          );
        }
        if (!_isCreated(unit.card)) _discardLands(unit.card, burnEnd + ghost, mine: mine);
        end = math.max(end, math.max(burnEnd + ghost, burnStart + burn * 0.4 + ash));
      }
      end = math.max(end, burnEnd + _ms(StageTokens.fade));
      freeAt = burnEnd;
      discardAt = burnEnd + ghost;
    }
    // Созданные карты (Приманка) встают на место сгоревших, когда место освободилось; карты под Берсерками уходят в сброс.
    for (final (i, event) in related) {
      if (done.contains(i)) continue;
      switch (event) {
        case CreatedCardPlaced():
          done.add(i);
          end = math.max(end, _created(event, freeAt));
        case CardDiscarded(:final owner, :final card):
          done.add(i);
          _discardLands(card, discardAt, mine: _mine(owner));
        default:
          break;
      }
    }
    _requestSettle(freeAt);
    return math.max(end, freeAt + _ms(StageTokens.roll));
  }
}
