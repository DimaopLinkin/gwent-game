part of 'stage_builder.dart';

const Color _gold = Color(0xFFE6C67E);

/// Розыгрыш карты из руки: сцены отряда и особых карт.
extension _PlayScenes on StageScriptBuilder {
  void _play(List<GameEvent> events, int index, Set<int> done) {
    final played = events[index] as CardPlayed;
    done.add(index);
    final related = _related(events, index);
    var at = _cursor;
    if (!_mine(played.seat)) at = _think(at);
    final end = switch (catalog.card(played.card.cardId)) {
      UnitCardDefinition() => _unitCard(played, related, done, at),
      SpecialCardDefinition(ability: HornCardAbility()) => _hornCard(played, related, done, at, mardrem: false),
      SpecialCardDefinition(ability: MardremCardAbility()) => _hornCard(played, related, done, at, mardrem: true),
      SpecialCardDefinition(:final WeatherAbility ability) => _weatherCard(played, related, done, at, ability),
      SpecialCardDefinition(ability: ClearWeatherAbility()) => _clearCard(played, related, done, at),
      SpecialCardDefinition(ability: ScorchAbility()) => _scorchCard(played, related, done, at),
      SpecialCardDefinition(ability: DecoyAbility()) => _decoyCard(played, related, done, at),
      null => at,
    };
    _cursor = math.max(_cursor, end);
  }

  /// Слот карты в моей руке до хода; колода, если карты в руке не было.
  StagePlace _handPlace(CardInstance card) {
    final hand = prev.me.hand ?? const <CardInstance>[];
    final index = hand.indexWhere((candidate) => candidate.id == card.id);
    return index < 0 ? const DeckPlace(mine: true) : HandPlace(index, hand.length);
  }

  /// Слот карты в моей руке после хода.
  StagePlace? _nextHandPlace(CardInstance card) {
    final hand = next.me.hand ?? const <CardInstance>[];
    final index = hand.indexWhere((candidate) => candidate.id == card.id);
    return index < 0 ? null : HandPlace(index, hand.length);
  }

  /// Карта, лежащая в моей колоде или в руке соперника, до выхода на поле: откуда она вылетает.
  StagePlace _sourceOf(CardInstance card, {required bool mine}) =>
      mine ? _handPlace(card) : const BarHandPlace(mine: false);

  // Отряд.

  double _unitCard(CardPlayed played, List<(int, GameEvent)> related, Set<int> done, double at) {
    final placement = related
        .where(
          (entry) => switch (entry.$2) {
            UnitPlaced(:final card, :final source) => card.id == played.card.id && source == EntrySource.hand,
            _ => false,
          },
        )
        .firstOrNull;
    if (placement == null) return at;
    done.add(placement.$1);
    final placed = placement.$2 as UnitPlaced;
    final target = (mine: _mine(placed.side), row: placed.row);
    final mineSeat = _mine(played.seat);
    _bump(StageCounter.hand, -1, at, mine: mineSeat);
    final landed = mineSeat
        ? _flyMine(played.card, _handPlace(played.card), target, at)
        : _revealAndEnter(played.card, target, at, spy: target.mine);
    _unitSounds(played.card, placed.row, target, landed);
    final ability = catalog.card(played.card.cardId);
    if (ability is UnitCardDefinition) {
      switch (ability.ability) {
        case UnitHornAbility():
          _hornGlow(target, landed, mardrem: false);
        case MardremAuraAbility():
          _hornGlow(target, landed, mardrem: true);
        default:
          break;
      }
    }
    final end = _effects(related, done, landed, actor: played.seat);
    final settle = math.max(end, landed);
    _requestSettle(settle, stagger: _ms(100));
    return settle + _ms(StageTokens.roll);
  }

  /// Звуки отряда, вставшего в ряд из руки в момент [at]: ряд (или герой), затем способность. Как в оригинале, шпион
  /// звука ряда не даёт, а Крепкая связь звучит, только если в ряду есть пара.
  void _unitSounds(CardInstance card, Row row, RowRef target, double at) {
    final definition = catalog.card(card.cardId);
    if (definition is! UnitCardDefinition) return;
    final ability = definition.ability;
    if (ability is! SpyAbility) _sound(definition.isHero ? SoundEffect.hero : soundOfRow(row), at);
    final effect = soundOfUnitAbility(ability);
    if (effect == null) return;
    final paired = _rows[target]!.order.any(
      (draft) => draft.card.id != card.id && draft.card.cardId == card.cardId && draft.after != null,
    );
    if (ability is TightBondAbility && !paired) return;
    _sound(effect, at);
  }

  /// Моя карта летит из [from] в ряд [target] по дуге и садится в него: возвращает момент посадки.
  double _flyMine(CardInstance card, StagePlace from, RowRef target, double at) {
    final draft = _ensureDraft(card, target);
    draft.reserveAt = at;
    if (_rm) {
      draft.showAt = at;
      draft.fadeIn = _ms(StageTokens.fade);
      return at + draft.fadeIn;
    }
    final flight = _ms(StageTokens.flight);
    final land = _ms(StageTokens.land);
    final place = RowCardPlace(mine: target.mine, row: target.row, card: card.id);
    final ref = CardFaceRef(card, mine: true);
    _beats
      ..add(FlightBeat(ref: ref, from: from, to: place, start: at, duration: flight, arc: -36, boost: 0.12))
      ..add(_landing(ref, place, at + flight, land));
    return draft.showAt = at + flight + land;
  }

  /// Посадка карты в ряд: размер 1,1 → 1 и тень.
  FlightBeat _landing(StageCardRef ref, RowCardPlace place, double at, double land) => FlightBeat(
    ref: ref,
    from: place,
    to: place,
    start: at,
    duration: land,
    scaleFrom: 1.1,
    shadowTo: 0,
    size: CardSize.row,
  );

  /// Карта соперника вылетает рубашкой вверх, в центре разворачивается лицом, держится крупно с подписью и летит в ряд.
  double _revealAndEnter(CardInstance card, RowRef target, double at, {required bool spy}) {
    final draft = _ensureDraft(card, target);
    final hold = _ms(StageTokens.hold);
    final shown = _showCentered(card, mine: false, at: at, hold: hold, caption: true);
    draft.reserveAt = shown;
    if (_rm) {
      draft.showAt = shown;
      draft.fadeIn = _ms(StageTokens.fade);
      return shown + draft.fadeIn;
    }
    final flight = _ms(StageTokens.flightShort);
    final land = _ms(StageTokens.land);
    final place = RowCardPlace(mine: target.mine, row: target.row, card: card.id);
    final ref = CardFaceRef(card, mine: false);
    _beats
      ..add(
        FlightBeat(
          ref: ref,
          from: const CenterPlace(),
          to: place,
          start: shown,
          duration: flight,
          arc: -20,
          size: CardSize.grid,
        ),
      )
      ..add(_landing(ref, place, shown + flight, land));
    if (spy) {
      // Шпион соперника ложится в мой ряд: ряд-цель обведён золотом на время полёта.
      _beats.add(
        GlowBeat(
          place: RowPlace(mine: target.mine, row: target.row),
          color: _gold,
          start: shown - _ms(120),
          end: shown + flight + land + _ms(100),
        ),
      );
    }
    return draft.showAt = shown + flight + land;
  }

  /// Карта выходит в центр поля и держится [hold] мс. Возвращает момент, когда её можно уносить дальше.
  ///
  /// Моя карта летит из руки, карта соперника вылетает рубашкой из его панели и переворачивается лицом (200 мс).
  /// При «Уменьшить движение» карта проявляется на месте: длительность показа сохраняется, он нужен для чтения.
  double _showCentered(
    CardInstance card, {
    required bool mine,
    required double at,
    required double hold,
    bool caption = false,
  }) {
    const center = CenterPlace();
    final ref = CardFaceRef(card, mine: mine);
    final fly = _ms(StageTokens.flightShort - 40);
    final flip = _ms(StageTokens.flip);
    final fade = _ms(StageTokens.fade);
    double holdStart;
    if (_rm) {
      holdStart = at + fade;
      _beats.add(
        FlightBeat(
          ref: ref,
          from: center,
          to: center,
          start: at,
          duration: fade,
          opacityFrom: 0,
          size: CardSize.grid,
        ),
      );
    } else if (mine) {
      holdStart = at + fly;
      _beats.add(
        FlightBeat(
          ref: ref,
          from: _handPlace(card),
          to: center,
          start: at,
          duration: fly,
          boost: 0.06,
          size: CardSize.grid,
        ),
      );
    } else {
      holdStart = at + fly + flip;
      _beats
        ..add(
          FlightBeat(
            ref: ref,
            from: const BarHandPlace(mine: false),
            to: center,
            start: at,
            duration: fly,
            ryFrom: 180,
            ryTo: 180,
            size: CardSize.grid,
          ),
        )
        ..add(
          FlightBeat(
            ref: ref,
            from: center,
            to: center,
            start: at + fly,
            duration: flip,
            ryFrom: 180,
            size: CardSize.grid,
          ),
        );
    }
    final holdEnd = holdStart + hold;
    _beats.add(FlightBeat(ref: ref, from: center, to: center, start: holdStart, duration: hold, size: CardSize.grid));
    if (caption) {
      _beats.add(
        CaptionBeat(
          kind: CaptionKind.opponentPlays,
          card: card,
          start: holdStart,
          rise: holdStart + fade,
          fall: holdEnd - fade,
          end: holdEnd,
        ),
      );
    }
    return holdEnd;
  }

  // Особые карты.

  /// Командирский рог и Мардрём: карта крупно, затем в слот ряда; слот загорается, силы ряда удваиваются волной.
  double _hornCard(
    CardPlayed played,
    List<(int, GameEvent)> related,
    Set<int> done,
    double at, {
    required bool mardrem,
  }) {
    final slot = related
        .where(
          (entry) => switch (entry.$2) {
            SlotFilled(slot: CardSlot(:final card)) => card.id == played.card.id,
            _ => false,
          },
        )
        .firstOrNull;
    if (slot == null) return at;
    done.add(slot.$1);
    final filled = slot.$2 as SlotFilled;
    final mineSeat = _mine(played.seat);
    _bump(StageCounter.hand, -1, at, mine: mineSeat);
    final holdEnd = _showCentered(played.card, mine: mineSeat, at: at, hold: _ms(StageTokens.hold));
    final target = (mine: _mine(filled.side), row: filled.row);
    final place = HornPlace(mine: target.mine, row: target.row);
    final fly = _ms(280);
    var landed = holdEnd;
    if (!_rm) {
      _beats.add(
        FlightBeat(
          ref: CardFaceRef(played.card, mine: mineSeat),
          from: const CenterPlace(),
          to: place,
          start: holdEnd,
          duration: fly,
          arc: -20,
          shadowTo: 0,
          size: CardSize.grid,
        ),
      );
      landed = holdEnd + fly;
    }
    _rows[target]!.slotAt = landed;
    _hornGlow(target, landed, mardrem: mardrem);
    final end = _effects(related, done, landed + _ms(StageTokens.fan), actor: played.seat);
    _requestSettle(landed + _ms(StageTokens.fan), stagger: _ms(100));
    return math.max(end, landed + _ms(StageTokens.fan) + _ms(StageTokens.roll));
  }

  /// Слот рога загорается, по ряду проходит золотая (у Мардрёма тёмно-фиолетовая) волна слева направо.
  void _hornGlow(RowRef target, double at, {required bool mardrem}) {
    _sound(mardrem ? SoundEffect.mardroeme : SoundEffect.horn, at);
    final color = mardrem ? const Color(0xFF8F4FB5) : _gold;
    _beats
      ..add(
        GlowBeat(
          place: HornPlace(mine: target.mine, row: target.row),
          color: color,
          start: at,
          end: at + _ms(500),
        ),
      )
      ..add(
        GlowBeat(
          place: RowPlace(mine: target.mine, row: target.row),
          color: color,
          start: at,
          end: at + _ms(500),
          alpha: 0.5,
          kind: _rm ? GlowKind.wash : GlowKind.sweep,
          sweep: _rm ? 0 : _ms(StageTokens.wave * 1.4 ~/ 1),
        ),
      );
  }

  /// Чучело: две встречные дуги, карта из ряда в руку и Чучело на её место.
  double _decoyCard(CardPlayed played, List<(int, GameEvent)> related, Set<int> done, double at) {
    final swap = related.where((entry) => entry.$2 is UnitDecoyed).firstOrNull;
    if (swap == null) return at;
    done.add(swap.$1);
    final decoyed = swap.$2 as UnitDecoyed;
    final mineSeat = _mine(played.seat);
    final target = (mine: _mine(decoyed.seat), row: decoyed.row);
    _bump(StageCounter.hand, -1, at, mine: mineSeat);
    var start = at;
    if (!mineSeat) start = _showCentered(played.card, mine: false, at: at, hold: _ms(StageTokens.hold), caption: true);
    final flight = _ms(StageTokens.flight);
    final land = _ms(StageTokens.land);
    final returned = _endLife(decoyed.returned, target);
    final decoy = _ensureDraft(decoyed.decoy, target);
    final returnedPlace = RowCardPlace(mine: target.mine, row: target.row, card: decoyed.returned.id);
    final decoyPlace = RowCardPlace(mine: target.mine, row: target.row, card: decoyed.decoy.id);
    var end = start;
    if (_rm) {
      returned.removeAt = start;
      decoy
        ..reserveAt = start
        ..showAt = start
        ..fadeIn = _ms(StageTokens.fade);
      end = start + decoy.fadeIn;
    } else {
      returned
        ..hideAt = start
        ..removeAt = start + flight;
      decoy
        ..reserveAt = start + flight
        ..showAt = start + flight + land;
      final back = mineSeat ? _nextHandPlace(decoyed.returned) : const BarHandPlace(mine: false);
      _beats
        ..add(
          FlightBeat(
            ref: CardFaceRef(decoyed.decoy, mine: mineSeat),
            from: mineSeat ? _handPlace(played.card) : const CenterPlace(),
            to: returnedPlace,
            start: start,
            duration: flight,
            arc: -80,
            boost: 0.1,
          ),
        )
        ..add(_landing(CardFaceRef(decoyed.decoy, mine: mineSeat), decoyPlace, start + flight, land))
        ..add(
          FlightBeat(
            ref: CardFaceRef(decoyed.returned, mine: target.mine),
            from: returnedPlace,
            to: back ?? const DeckPlace(mine: true),
            start: start,
            duration: flight,
            arc: 80,
            boost: 0.1,
            size: CardSize.row,
          ),
        );
      if (back is HandPlace) _beats.add(HandHideBeat(card: decoyed.returned.id, until: start + flight));
      end = start + flight + land;
    }
    _sound(SoundEffect.decoy, start + (_rm ? 0 : flight));
    _bump(StageCounter.hand, 1, start + (_rm ? 0 : flight), mine: _mine(decoyed.seat));
    _requestSettle(start + (_rm ? 0 : flight));
    return math.max(end, start + (_rm ? 0 : flight) + _ms(StageTokens.roll));
  }

  // Погода.

  double _weatherCard(
    CardPlayed played,
    List<(int, GameEvent)> related,
    Set<int> done,
    double at,
    WeatherAbility ability,
  ) {
    final mineSeat = _mine(played.seat);
    _bump(StageCounter.hand, -1, at, mine: mineSeat);
    final holdEnd = _showCentered(played.card, mine: mineSeat, at: at, hold: _ms(StageTokens.holdWeather));
    final laid = related
        .where(
          (entry) => switch (entry.$2) {
            WeatherPlayed(:final card) => card.id == played.card.id,
            _ => false,
          },
        )
        .firstOrNull;
    final rows = ([...ability.rows]..sort((a, b) => a.index.compareTo(b.index)));
    final slotRow = rows.isEmpty ? Row.melee : rows.first;
    final fly = _ms(280);
    var landed = holdEnd;
    if (!_rm) {
      _beats.add(
        FlightBeat(
          ref: CardFaceRef(played.card, mine: mineSeat),
          from: const CenterPlace(),
          to: laid == null ? DiscardPlace(mine: mineSeat) : WeatherSlotPlace(slotRow),
          start: holdEnd,
          duration: fly,
          arc: -30,
          shadowTo: 0,
          size: CardSize.grid,
        ),
      );
      landed = holdEnd + fly;
    }
    if (laid == null) {
      // Такая погода уже лежит: карта сразу уходит в сброс.
      _discardLands(played.card, landed, mine: mineSeat);
      return landed;
    }
    done.add(laid.$1);
    final end = _weatherLands(rows, landed);
    return end;
  }

  /// Погода легла: слот горит, по рядам обоих игроков идёт волна, силы отрядов падают, у героев вспыхивает рамка.
  double _weatherLands(List<Row> rows, double at) {
    _sound(soundOfWeather(rows.toSet()), at);
    _slotsChange(at);
    final wave = _ms(StageTokens.wave);
    var last = at;
    for (var i = 0; i < rows.length; i++) {
      for (final mine in const [true, false]) {
        final ref = (mine: mine, row: rows[i]);
        final start = at + i * _ms(60);
        if (_rm) {
          _beats.add(
            GlowBeat(
              place: RowPlace(mine: mine, row: rows[i]),
              color: const Color(0xFFCDE4F5),
              start: start,
              end: start + _ms(StageTokens.fade) * 2,
              alpha: 0.4,
              kind: GlowKind.wash,
            ),
          );
          _rows[ref]!.weatherAt = start;
        } else {
          _beats.add(
            WaveBeat(
              place: RowPlace(mine: mine, row: rows[i]),
              start: start,
              duration: wave,
              storm: rows.length > 1,
            ),
          );
          _rows[ref]!.weatherAt = start + wave;
        }
        last = math.max(last, start + wave);
      }
    }
    final pulse = at + (_rm ? 0 : wave * 0.6);
    for (var i = 0; i < rows.length; i++) {
      for (final mine in const [true, false]) {
        final ref = (mine: mine, row: rows[i]);
        for (final draft in _rows[ref]!.order) {
          if (!_isHero(draft.card) || draft.before == null) continue;
          _beats.add(
            GlowBeat(
              place: RowCardPlace(mine: mine, row: rows[i], card: draft.card.id),
              color: _gold,
              start: pulse + _ms(60),
              end: pulse + _ms(500),
              rise: pulse + _ms(160),
              fall: pulse + _ms(300),
            ),
          );
        }
      }
    }
    _requestSettle(pulse + _ms(60), stagger: _ms(70));
    return math.max(last, pulse + _ms(60) + _ms(StageTokens.roll));
  }

  bool _isCreated(CardInstance card) => switch (catalog.card(card.cardId)) {
    UnitCardDefinition(:final isCreated) => isCreated,
    _ => false,
  };

  bool _isHero(CardInstance card) => switch (catalog.card(card.cardId)) {
    UnitCardDefinition(:final isHero) => isHero,
    _ => false,
  };

  /// Ясное небо: карта крупно, слот гаснет, эффект «выдыхается» волной, силы возвращаются.
  double _clearCard(CardPlayed played, List<(int, GameEvent)> related, Set<int> done, double at) {
    final mineSeat = _mine(played.seat);
    _bump(StageCounter.hand, -1, at, mine: mineSeat);
    final holdEnd = _showCentered(played.card, mine: mineSeat, at: at, hold: _ms(StageTokens.holdWeather));
    final fly = _ms(280);
    var landed = holdEnd;
    if (!_rm) {
      _beats.add(
        FlightBeat(
          ref: CardFaceRef(played.card, mine: mineSeat),
          from: const CenterPlace(),
          to: const WeatherSlotPlace(Row.ranged),
          start: holdEnd,
          duration: fly,
          arc: -30,
          shadowTo: 0,
          opacityTo: 0,
          size: CardSize.grid,
        ),
      );
      landed = holdEnd + fly;
    }
    return _clearsWeather(related, done, landed, mineSeat: mineSeat, cards: [played.card]);
  }

  /// Погода снята в момент [at]; [cards] — карты, которые уйдут в сброс владельцев вместе с ней.
  double _clearsWeather(
    List<(int, GameEvent)> related,
    Set<int> done,
    double at, {
    required bool mineSeat,
    List<CardInstance> cards = const [],
  }) {
    _sound(SoundEffect.clearWeather, at);
    _slotsChange(at);
    final clear = _ms(StageTokens.clear);
    for (final mine in const [true, false]) {
      for (final row in Row.values) {
        final ref = (mine: mine, row: row);
        final row0 = _rows[ref]!;
        if (!row0.weatherBefore || row0.weatherAfter) continue;
        row0.weatherAt = at;
        _beats.add(
          _rm
              ? GlowBeat(
                  place: RowPlace(mine: mine, row: row),
                  color: const Color(0xFFD6D0C4),
                  start: at,
                  end: at + _ms(StageTokens.fade),
                  alpha: 0.3,
                  kind: GlowKind.wash,
                )
              : WaveBeat(
                  place: RowPlace(mine: mine, row: row),
                  start: at,
                  duration: clear,
                  reverse: true,
                ),
        );
      }
    }
    for (final (i, event) in related) {
      if (event is CardDiscarded && !done.contains(i)) {
        done.add(i);
        _discardLands(event.card, at + clear, mine: _mine(event.owner));
      }
    }
    for (final card in cards) {
      _discardLands(card, at + clear, mine: mineSeat);
    }
    final pulse = at + (_rm ? 0 : clear * 0.45);
    _requestSettle(pulse, stagger: _ms(70));
    return math.max(at + clear, pulse + _ms(StageTokens.roll));
  }
}
