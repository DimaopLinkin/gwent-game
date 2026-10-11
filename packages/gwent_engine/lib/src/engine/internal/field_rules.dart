import 'package:gwent_engine/src/cards/card_definition.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/cards/special_ability.dart';
import 'package:gwent_engine/src/cards/unit_ability.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/entry_source.dart';
import 'package:gwent_engine/src/state/field_card.dart';
import 'package:gwent_engine/src/state/row_slot.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Карта на поле вместе с её местом.
typedef FieldTarget = ({Seat side, Row row, FieldCard card});

/// Правила поля: выкладка и уход карт, Приманка, слоты рога, Чучело и превращение Берсерков.
final class FieldRules {
  const FieldRules(this._ctx);

  final MatchContext _ctx;

  /// Кладёт отряд в ряд. Способности при выходе запускает `EnterAbilities`.
  void placeUnit(Seat side, Row row, CardInstance card, EntrySource source) {
    _ctx.player(side).rows[row]!.cards.add(FieldCard(card));
    _ctx.emit(UnitPlaced(side, row, card, source));
    transformBerserks();
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
