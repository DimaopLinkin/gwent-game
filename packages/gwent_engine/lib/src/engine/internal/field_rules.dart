import 'package:gwent_engine/src/cards/card_definition.dart';
import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/leader_ability.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/cards/special_ability.dart';
import 'package:gwent_engine/src/cards/unit_ability.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/engine/internal/strength_calculator.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/effect.dart';
import 'package:gwent_engine/src/state/entry_source.dart';
import 'package:gwent_engine/src/state/field_card.dart';
import 'package:gwent_engine/src/state/row_slot.dart';
import 'package:gwent_engine/src/state/seat.dart';
import 'package:gwent_engine/src/state/weather_card.dart';

/// Карта на поле вместе с её местом.
typedef FieldTarget = ({Seat side, Row row, FieldCard card});

/// Правила поля: выкладка отрядов, способности при выходе, погода, слоты рога, Казнь, Чучело и Берсерки.
final class FieldRules {
  FieldRules(this._ctx) : _calculator = StrengthCalculator(_ctx.catalog);

  final MatchContext _ctx;
  final StrengthCalculator _calculator;

  /// Ряды под действующей погодой.
  Set<Row> weatherRows() => {
    for (final weather in _ctx.draft.weather)
      if (_ctx.definition(weather.card) case SpecialCardDefinition(ability: WeatherAbility(:final rows))) ...rows,
  };

  /// Текущая сила карт ряда в порядке выкладки.
  List<int> strengths(Seat side, Row row) {
    final draftRow = _ctx.player(side).rows[row]!;
    return _calculator.row(draftRow.cards, draftRow.slot, conditions(side, row));
  }

  /// Условия ряда для расчёта силы.
  RowConditions conditions(Seat side, Row row) => RowConditions(
    weather: weatherRows().contains(row),
    halveWeather: _ctx.leaderAbility(side) is HalveWeatherAbility,
    doubleSpies: _ctx.anyLeader((ability) => ability is DoubleSpiesAbility),
  );

  /// Сила ряда: сумма всех его карт, включая героев.
  int rowTotal(Seat side, Row row) => strengths(side, row).fold(0, (sum, strength) => sum + strength);

  /// Очки стороны: сумма трёх рядов.
  int score(Seat side) => Row.values.fold(0, (sum, row) => sum + rowTotal(side, row));

  /// Кладёт отряд в ряд. Способности при выходе запускает [triggerOnEnter].
  void placeUnit(Seat side, Row row, CardInstance card, EntrySource source) {
    _ctx.player(side).rows[row]!.cards.add(FieldCard(card));
    _ctx.emit(UnitPlaced(side, row, card, source));
    transformBerserks();
  }

  /// Способности при выходе карты [card], которую выложил игрок [player] (раздел 9.2).
  void triggerOnEnter(Seat player, CardInstance card, EntrySource source) {
    switch (_ctx.unit(card)?.ability) {
      case SpyAbility(:final draw):
        _ctx.draw(player, draw);
      case MedicAbility():
        _ctx.draft.effects.add(MedicEffect(player));
      case MusterAbility(:final summons):
        if (source != EntrySource.muster) _muster(player, summons);
      case ScorchRowAbility(:final row, :final threshold):
        scorchRow(player.opponent, row, threshold);
      case ScorchAllAbility():
        scorchAll();
      case TightBondAbility() ||
          MoraleBoostAbility() ||
          UnitHornAbility() ||
          BaitAbility() ||
          BerserkAbility() ||
          MardremAuraAbility() ||
          null:
        break;
    }
  }

  /// Двойник: все карты [summons] из колоды, затем из руки выходят на поле (раздел 9.4).
  void _muster(Seat seat, List<CardId> summons) {
    final player = _ctx.player(seat);
    final summoned = <CardInstance>[];
    for (final id in summons) {
      for (final zone in [player.deck, player.hand]) {
        summoned.addAll(zone.where((card) => card.cardId == id));
        zone.removeWhere((card) => card.cardId == id);
      }
    }
    // Стек: последний добавленный эффект выполняется первым, поэтому кладём в обратном порядке.
    for (final card in summoned.reversed) {
      _ctx.draft.effects.add(EnterFieldEffect(seat, card, EntrySource.muster, row: _ctx.unit(card)!.placement.row));
    }
  }

  /// Превращает Берсерков в рядах с Мардрёмом (раздел 9.4).
  void transformBerserks() {
    for (final side in Seat.values) {
      for (final MapEntry(key: row, value: draftRow) in _ctx.player(side).rows.entries) {
        final mardrem =
            _isMardremSlot(draftRow.slot) ||
            draftRow.cards.any((card) => _ctx.unit(card.card)?.ability is MardremAuraAbility);
        if (!mardrem) continue;
        for (var i = 0; i < draftRow.cards.length; i++) {
          final fieldCard = draftRow.cards[i];
          if (_ctx.unit(fieldCard.card)?.ability case BerserkAbility(:final transformsInto)) {
            final created = _ctx.create(transformsInto);
            draftRow.cards[i] = FieldCard(created, beneath: fieldCard.card, kept: fieldCard.kept);
            _ctx.emit(BerserkTransformed(side, row, berserk: fieldCard.card, into: created));
          }
        }
      }
    }
  }

  bool _isMardremSlot(RowSlot? slot) => switch (slot) {
    CardSlot(:final card) => switch (_ctx.definition(card)) {
      SpecialCardDefinition(ability: MardremCardAbility()) => true,
      _ => false,
    },
    LeaderHornSlot() || null => false,
  };

  /// Карта уходит с поля в отбой стороны, на которой лежала; созданная выходит из игры, Берсерк под ней
  /// уходит в отбой (разделы 1.1, 1.2, 9.4). Приманку обрабатывает вызывающий код.
  void leaveField(Seat side, FieldCard card) {
    if (card.beneath case final beneath?) _ctx.discard(side, beneath);
    _ctx.discard(side, card.card);
  }

  /// Уничтожает карты; Приманка сразу призывает свою карту на место уничтоженной.
  void destroy(List<FieldTarget> targets) {
    if (targets.isEmpty) return;
    _ctx.emit(
      UnitsDestroyed(List.unmodifiable([for (final t in targets) DestroyedUnit(t.side, t.row, t.card.card)])),
    );
    final destroyed = {for (final target in targets) target.card.card.id};
    final elsewhere = <(Seat, Row, CardInstance)>[];
    for (final side in Seat.values) {
      for (final MapEntry(key: row, value: draftRow) in _ctx.player(side).rows.entries) {
        final remaining = <FieldCard>[];
        for (final fieldCard in draftRow.cards) {
          if (!destroyed.contains(fieldCard.card.id)) {
            remaining.add(fieldCard);
            continue;
          }
          leaveField(side, fieldCard);
          if (_ctx.unit(fieldCard.card)?.ability case BaitAbility(:final summon)) {
            final created = _ctx.create(summon);
            final summonRow = _ctx.unit(created)!.placement.row ?? row;
            if (summonRow == row) {
              remaining.add(FieldCard(created));
              _ctx.emit(CreatedCardPlaced(side, row, created));
            } else {
              elsewhere.add((side, summonRow, created));
            }
          }
        }
        draftRow.cards
          ..clear()
          ..addAll(remaining);
      }
    }
    for (final (side, row, created) in elsewhere) {
      placeCreated(side, row, created);
    }
    transformBerserks();
  }

  /// Кладёт созданную карту в конец ряда.
  void placeCreated(Seat side, Row row, CardInstance card) {
    _ctx.player(side).rows[row]!.cards.add(FieldCard(card));
    _ctx.emit(CreatedCardPlaced(side, row, card));
  }

  /// Казнь всего поля: сильнейшие обычные отряды у обоих игроков (раздел 9.3).
  void scorchAll() {
    final candidates = <(FieldTarget, int)>[
      for (final side in Seat.values)
        for (final row in Row.values) ..._normalUnits(side, row),
    ];
    destroy(_strongest(candidates));
  }

  /// Казнь по ряду: если сила ряда не меньше [threshold], сильнейшие обычные отряды ряда (раздел 9.4).
  void scorchRow(Seat side, Row row, int threshold) {
    if (rowTotal(side, row) < threshold) return;
    destroy(_strongest(_normalUnits(side, row)));
  }

  List<(FieldTarget, int)> _normalUnits(Seat side, Row row) {
    final cards = _ctx.player(side).rows[row]!.cards;
    final strengths = this.strengths(side, row);
    return [
      for (var i = 0; i < cards.length; i++)
        if (_ctx.isNormalUnit(cards[i].card)) ((side: side, row: row, card: cards[i]), strengths[i]),
    ];
  }

  static List<FieldTarget> _strongest(List<(FieldTarget, int)> candidates) {
    if (candidates.isEmpty) return const [];
    final max = candidates.map((candidate) => candidate.$2).reduce((a, b) => a > b ? a : b);
    return [
      for (final (target, strength) in candidates)
        if (strength == max) target,
    ];
  }

  /// Карта погоды или Ясное небо от игрока [owner] (раздел 9.3).
  void playWeather(Seat owner, CardInstance card) {
    switch (_ctx.definition(card)) {
      case SpecialCardDefinition(ability: WeatherAbility()):
        if (_ctx.draft.weather.any((weather) => weather.card.cardId == card.cardId)) {
          _ctx.discard(owner, card);
        } else {
          _ctx.draft.weather.add(WeatherCard(card, owner));
          _ctx.emit(WeatherPlayed(owner, card));
        }
      case SpecialCardDefinition(ability: ClearWeatherAbility()):
        clearWeather();
        _ctx.discard(owner, card);
      case SpecialCardDefinition() || UnitCardDefinition():
        throw StateError('Карта ${card.cardId} не погода');
    }
  }

  /// Снимает всю погоду: карты уходят в отбой своих хозяев.
  void clearWeather() {
    final weather = [..._ctx.draft.weather];
    _ctx.draft.weather.clear();
    _ctx.emit(const WeatherCleared());
    for (final card in weather) {
      _ctx.discard(card.owner, card.card);
    }
  }

  bool slotFree(Seat side, Row row) => _ctx.player(side).rows[row]!.slot == null;

  /// Кладёт карту или рог лидера в слот рога ряда.
  void fillSlot(Seat side, Row row, RowSlot slot) {
    _ctx.player(side).rows[row]!.slot = slot;
    _ctx.emit(SlotFilled(side, row, slot));
    transformBerserks();
  }

  /// Цели Чучела: обычные отряды на своей стороне, включая шпионов соперника и созданные карты (раздел 9.3).
  List<FieldTarget> decoyTargets(Seat seat) => [
    for (final MapEntry(key: row, value: draftRow) in _ctx.player(seat).rows.entries)
      for (final card in draftRow.cards)
        if (_ctx.isNormalUnit(card.card)) (side: seat, row: row, card: card),
  ];

  /// Чучело встаёт на место цели, цель возвращается в руку игрока.
  void decoy(Seat seat, CardInstance decoy, FieldTarget target) {
    final cards = _ctx.player(seat).rows[target.row]!.cards;
    final index = cards.indexWhere((card) => card.card.id == target.card.card.id);
    cards[index] = FieldCard(decoy);
    _ctx.player(seat).hand.add(target.card.card);
    _ctx.emit(UnitDecoyed(seat, target.row, decoy: decoy, returned: target.card.card));
    if (target.card.beneath case final beneath?) _ctx.discard(seat, beneath);
  }
}
