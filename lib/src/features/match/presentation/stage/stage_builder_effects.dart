part of 'stage_builder.dart';

/// Способности, которые идут вслед за розыгрышем карты, и события без розыгрыша: добор, Двойник, Медик, лидер.
extension _EffectScenes on StageScriptBuilder {
  /// Разбирает [related] по порядку, начиная с момента [at]. Возвращает момент, когда всё закончилось.
  double _effects(List<(int, GameEvent)> related, Set<int> done, double at, {required Seat actor}) {
    var end = at;
    var musterAt = -1.0;
    var musterStep = 0;
    for (final (i, event) in related) {
      if (done.contains(i)) continue;
      switch (event) {
        case CardsDrawn(:final seat, :final cards):
          done.add(i);
          end = math.max(end, _draw(mine: _mine(seat), cards: cards, count: cards.length, at: end));
        case CardsDrawnHidden(:final seat, :final count):
          done.add(i);
          end = math.max(end, _draw(mine: _mine(seat), cards: null, count: count, at: end));
        case UnitPlaced(:final source) when source != EntrySource.hand:
          done.add(i);
          if (source.isMuster) {
            if (musterAt < 0) musterAt = end;
            end = math.max(end, _enterFromZone(event, musterAt + musterStep * _ms(StageTokens.twin), actor));
            musterStep++;
          } else {
            end = math.max(end, _enterFromZone(event, end, actor));
          }
        case BerserkTransformed():
          done.add(i);
          end = math.max(end, _morph(event, end));
        case UnitsDestroyed():
          end = math.max(end, _scorchResolve(related, done, end));
        case CreatedCardPlaced():
          done.add(i);
          end = math.max(end, _created(event, end));
        case CardDiscarded(:final owner, :final card):
          done.add(i);
          _discardLands(card, end, mine: _mine(owner));
        default:
          break;
      }
    }
    return end;
  }

  /// Карта выходит на поле не из руки: из колоды, руки (Двойник) или сброса (Медик). Карту из сброса берёт [actor]:
  /// шпиона, возвращённого Медиком, он кладёт на сторону соперника, но достаёт из своего сброса.
  double _enterFromZone(UnitPlaced placed, double start, Seat actor) {
    final card = placed.card;
    final mine = _mine(placed.side);
    final target = (mine: mine, row: placed.row);
    final from = switch (placed.source) {
      EntrySource.musterFromDeck => DeckPlace(mine: mine),
      EntrySource.musterFromHand => mine ? _handPlace(card) : BarHandPlace(mine: mine),
      EntrySource.medic || EntrySource.perk => DiscardPlace(mine: _mine(actor)),
      EntrySource.hand => _sourceOf(card, mine: mine),
    };
    switch (placed.source) {
      case EntrySource.musterFromDeck:
        _bump(StageCounter.deck, -1, start, mine: mine);
      case EntrySource.musterFromHand:
        _bump(StageCounter.hand, -1, start, mine: mine);
      case EntrySource.medic || EntrySource.perk:
        _discardLeaves(card, start, mine: _mine(actor));
      case EntrySource.hand:
        break;
    }
    final draft = _ensureDraft(card, target);
    draft.reserveAt = start;
    if (_rm) {
      draft
        ..showAt = start
        ..fadeIn = _ms(StageTokens.fade);
      return start + draft.fadeIn;
    }
    final flight = _ms(placed.source == EntrySource.medic ? StageTokens.flightShort : StageTokens.flight);
    final land = _ms(StageTokens.land);
    final place = RowCardPlace(mine: mine, row: placed.row, card: card.id);
    final ref = CardFaceRef(card, mine: mine);
    final fromDeck = placed.source == EntrySource.musterFromDeck;
    _beats
      ..add(
        FlightBeat(
          ref: ref,
          from: from,
          to: place,
          start: start,
          duration: flight,
          arc: -28,
          boost: 0.08,
          ryFrom: fromDeck ? 180 : 0,
          size: from is DiscardPlace || from is DeckPlace ? CardSize.mini : CardSize.hand,
          scaleFrom: from is DiscardPlace || from is DeckPlace ? 1 : 1,
        ),
      )
      ..add(_landing(ref, place, start + flight, land));
    return draft.showAt = start + flight + land;
  }

  /// Берсерк разворачивается и становится медведем.
  double _morph(BerserkTransformed event, double at) {
    final mine = _mine(event.side);
    final berserk = _ensureDraft(event.berserk, (mine: mine, row: event.row));
    final bear = _ensureDraft(event.into, (mine: mine, row: event.row));
    if (_rm) {
      berserk.removeAt = at;
      bear
        ..reserveAt = at
        ..showAt = at
        ..fadeIn = _ms(StageTokens.fade);
      _requestSettle(at, stagger: _ms(70));
      return at + bear.fadeIn;
    }
    final morph = _ms(StageTokens.morph);
    berserk
      ..hideAt = at
      ..removeAt = at + morph;
    bear
      ..reserveAt = at + morph
      ..showAt = at + morph;
    _beats.add(
      MorphBeat(
        place: RowCardPlace(mine: mine, row: event.row, card: event.berserk.id),
        from: event.berserk,
        to: event.into,
        start: at,
        duration: morph,
      ),
    );
    _requestSettle(at + morph, stagger: _ms(70));
    return at + morph + _ms(StageTokens.roll);
  }

  /// Созданная карта (Приманка на месте сгоревшей) появляется на месте.
  double _created(CreatedCardPlaced event, double at) {
    final mine = _mine(event.side);
    final draft = _ensureDraft(event.card, (mine: mine, row: event.row))
      ..reserveAt = at
      ..showAt = at
      ..fadeIn = _ms(StageTokens.fade);
    return at + draft.fadeIn;
  }

  /// Добор: карты вылетают из колоды одна за другой, у меня разворачиваются лицом и встают в руку.
  double _draw({required bool mine, required List<CardInstance>? cards, required int count, required double at}) {
    var end = at;
    final flight = _ms(StageTokens.flight);
    for (var k = 0; k < count; k++) {
      final start = at + k * _ms(StageTokens.twin);
      final card = cards?[k];
      _bump(StageCounter.deck, -1, start, mine: mine);
      if (_rm) {
        _bump(StageCounter.hand, 1, start, mine: mine);
        end = math.max(end, start);
        continue;
      }
      final to = mine && card != null ? (_nextHandPlace(card) ?? BarHandPlace(mine: mine)) : BarHandPlace(mine: mine);
      _beats.add(
        FlightBeat(
          ref: card == null ? CardBackRef(mine: mine) : CardFaceRef(card, mine: mine),
          from: DeckPlace(mine: mine),
          to: to,
          start: start,
          duration: flight,
          arc: -24,
          ryFrom: 180,
          ryTo: mine && card != null ? 0 : 180,
          scaleFrom: 0.5,
          scaleTo: mine ? 1 : 0.5,
          size: mine ? CardSize.hand : CardSize.mini,
        ),
      );
      if (card != null && mine) _beats.add(HandHideBeat(card: card.id, until: start + flight));
      _bump(StageCounter.hand, 1, start + flight, mine: mine);
      end = math.max(end, start + flight);
    }
    return end;
  }

  /// События без розыгрыша карты: добор, Двойник, Медик и тому подобное, пришедшие отдельным обновлением.
  void _standalone(List<GameEvent> events, int index, Set<int> done) {
    final related = [(index, events[index]), ..._related(events, index)];
    final seat = switch (events[index]) {
      UnitPlaced(:final side) => side,
      CardsDrawn(:final seat) => seat,
      CardsDrawnHidden(:final seat) => seat,
      _ => viewer,
    };
    final end = _effects(related, done, _cursor, actor: seat);
    _requestSettle(end, stagger: _ms(70));
    _cursor = math.max(_cursor, end);
  }

  /// Способность лидера: мини-карта выходит в центр и держится, затем её действие.
  void _leader(List<GameEvent> events, int index, Set<int> done) {
    final used = events[index] as LeaderUsed;
    done.add(index);
    final related = _related(events, index);
    final mine = _mine(used.seat);
    var at = _cursor;
    if (!mine) at = _think(at);
    final hold = _ms(StageTokens.leader);
    final fly = _ms(StageTokens.flightShort);
    const center = MiniCenterPlace();
    final ref = LeaderRef(mine: mine);
    const zoom = 3.0;
    var effectAt = at + hold;
    if (_rm) {
      _beats.add(
        FlightBeat(
          ref: ref,
          from: center,
          to: center,
          start: at,
          duration: hold,
          opacityFrom: 0,
          scaleFrom: zoom,
          scaleTo: zoom,
          size: CardSize.mini,
        ),
      );
    } else {
      effectAt = at + fly + hold;
      _beats
        ..add(
          FlightBeat(
            ref: ref,
            from: LeaderPlace(mine: mine),
            to: center,
            start: at,
            duration: fly,
            scaleTo: zoom,
            size: CardSize.mini,
          ),
        )
        ..add(
          FlightBeat(
            ref: ref,
            from: center,
            to: center,
            start: at + fly,
            duration: hold,
            scaleFrom: zoom,
            scaleTo: zoom,
            size: CardSize.mini,
          ),
        )
        ..add(
          FlightBeat(
            ref: ref,
            from: center,
            to: LeaderPlace(mine: mine),
            start: effectAt,
            duration: fly,
            scaleFrom: zoom,
            size: CardSize.mini,
          ),
        );
    }
    _beats.add(LeaderUsedBeat(mine: mine, at: effectAt, before: _leaderBefore[mine] ?? false));
    var end = effectAt;
    for (final (i, event) in related) {
      if (done.contains(i)) continue;
      switch (event) {
        case SlotFilled(:final side, :final row, slot: LeaderHornSlot()):
          done.add(i);
          final target = (mine: _mine(side), row: row);
          _rows[target]!.slotAt = effectAt;
          _hornGlow(target, effectAt, mardrem: false);
          _requestSettle(effectAt + _ms(StageTokens.fan), stagger: _ms(100));
          end = math.max(end, effectAt + _ms(StageTokens.fan) + _ms(StageTokens.roll));
        case WeatherPlayed(:final owner, :final card):
          done.add(i);
          final ability = switch (catalog.card(card.cardId)) {
            SpecialCardDefinition(ability: final WeatherAbility weather) => weather,
            _ => null,
          };
          if (ability == null) break;
          final rows = [...ability.rows]..sort((a, b) => a.index.compareTo(b.index));
          var landed = effectAt;
          if (!_rm) {
            const flightMs = StageTokens.flight;
            _bump(StageCounter.deck, -1, effectAt, mine: _mine(owner));
            _beats.add(
              FlightBeat(
                ref: CardFaceRef(card, mine: _mine(owner)),
                from: DeckPlace(mine: _mine(owner)),
                to: WeatherSlotPlace(rows.isEmpty ? Row.melee : rows.first),
                start: effectAt,
                duration: _ms(flightMs),
                arc: -30,
                shadowTo: 0,
                size: CardSize.mini,
              ),
            );
            landed = effectAt + _ms(flightMs);
          }
          end = math.max(end, _weatherLands(rows, landed));
        case WeatherCleared():
          done.add(i);
          end = math.max(end, _clearsWeather(related, done, effectAt, mineSeat: mine));
        case UnitsDestroyed():
          end = math.max(end, _scorchResolve(related, done, effectAt));
        default:
          end = math.max(end, _effects([(i, event)], done, effectAt, actor: used.seat));
      }
    }
    _requestSettle(end, stagger: _ms(70));
    _cursor = math.max(_cursor, end);
  }
}
