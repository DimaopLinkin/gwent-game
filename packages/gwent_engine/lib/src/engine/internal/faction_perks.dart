import 'package:gwent_engine/src/cards/faction.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Перки фракций, которые срабатывают между раундами (разделы 6 и 11). Нильфгаард и Скоя'таэли действуют
/// в итоге раунда и при подготовке партии.
final class FactionPerks {
  const FactionPerks(this._ctx);

  /// Раунд, в начале которого срабатывает перк Скеллиге.
  static const int _skelligeRound = 3;

  /// Сколько карт возвращает перк Скеллиге.
  static const int _skelligeCards = 2;

  /// Сколько карт берёт игрок Королевств Севера после выигранного раунда.
  static const int _northernDraw = 1;

  final MatchContext _ctx;

  /// Чудовища: случайная карта отряда своей стороны остаётся на поле. Игроки по порядку [order].
  void keepRandomUnits(List<Seat> order) {
    for (final seat in order) {
      if (_ctx.player(seat).faction.perk == FactionPerk.keepRandomUnit) _keepRandomUnit(seat);
    }
  }

  void _keepRandomUnit(Seat seat) {
    final candidates = [
      for (final MapEntry(key: row, value: draftRow) in _ctx.player(seat).rows.entries)
        for (var i = 0; i < draftRow.cards.length; i++)
          if (_ctx.unit(draftRow.cards[i].card) != null) (row, i),
    ];
    if (candidates.isEmpty) return;
    final (row, index) = candidates[_ctx.random(candidates.length)];
    final cards = _ctx.player(seat).rows[row]!.cards;
    cards[index] = cards[index].copyWith(kept: true);
    _ctx.emit(UnitKept(seat, row, cards[index].card));
  }

  /// Королевства Севера: победитель прошлого раунда берёт карту.
  void drawForRoundWinner(Seat? previousWinner) {
    if (previousWinner != null && _ctx.player(previousWinner).faction.perk == FactionPerk.drawOnRoundWin) {
      _ctx.draw(previousWinner, _northernDraw);
    }
  }

  /// Снимает пометку Чудовищ: оставленная карта уйдёт с поля в конце этого раунда.
  void releaseKeptUnits() {
    for (final seat in Seat.values) {
      for (final draftRow in _ctx.player(seat).rows.values) {
        for (var i = 0; i < draftRow.cards.length; i++) {
          if (draftRow.cards[i].kept) draftRow.cards[i] = draftRow.cards[i].copyWith(kept: false);
        }
      }
    }
  }

  /// Скеллиге: в раунде [round] две случайные карты отрядов из отбоя возвращаются на поле. Карты убираются
  /// из отбоя и возвращаются по порядку выхода; первым выбирает [starter].
  List<(Seat, CardInstance)> reviveUnits(int round, Seat starter) {
    if (round != _skelligeRound) return const [];
    return [
      for (final seat in [starter, starter.opponent])
        if (_ctx.player(seat).faction.perk == FactionPerk.reviveInFinalRound) ..._revive(seat),
    ];
  }

  Iterable<(Seat, CardInstance)> _revive(Seat seat) {
    final discard = _ctx.player(seat).discard;
    final picked = _ctx.pick(discard.where(_ctx.isNormalUnit).toList(), _skelligeCards);
    discard.removeWhere(picked.contains);
    return picked.map((card) => (seat, card));
  }
}
