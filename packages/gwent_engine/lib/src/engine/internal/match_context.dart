import 'package:gwent_engine/src/cards/card_catalog.dart';
import 'package:gwent_engine/src/cards/card_definition.dart';
import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/leader_ability.dart';
import 'package:gwent_engine/src/engine/internal/draft.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/rules/game_rules.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Общий контекст одного `apply`: черновик партии, справочник, параметры и накопленные события.
final class MatchContext {
  MatchContext(this.draft, this.catalog, this.rules);

  final Draft draft;
  final CardCatalog catalog;
  final GameRules rules;
  final List<GameEvent> events = [];

  void emit(GameEvent event) => events.add(event);

  DraftPlayer player(Seat seat) => draft.player(seat);

  /// Определение карты. Колоды проверены при создании партии, поэтому карта есть в справочнике.
  CardDefinition definition(CardInstance card) => catalog.card(card.cardId)!;

  /// Определение карты отряда или `null` для специальной карты.
  UnitCardDefinition? unit(CardInstance card) => switch (definition(card)) {
    final UnitCardDefinition unit => unit,
    SpecialCardDefinition() => null,
  };

  /// Обычный отряд (не герой).
  bool isNormalUnit(CardInstance card) => unit(card)?.isHero == false;

  /// Действующая способность лидера игрока: `null`, если её отключило Белое Пламя.
  LeaderAbility? leaderAbility(Seat seat) {
    final player = this.player(seat);
    return player.leaderDisabled ? null : catalog.leader(player.leader)!.ability;
  }

  /// Действует ли пассивная способность у кого-то из игроков.
  bool anyLeader(bool Function(LeaderAbility ability) test) => Seat.values.any((seat) {
    final ability = leaderAbility(seat);
    return ability != null && test(ability);
  });

  /// Случайное число из `[0, max)` из генератора партии.
  int random(int max) {
    final (value, next) = draft.rng.nextInt(max);
    draft.rng = next;
    return value;
  }

  /// Перемешивание Фишера — Йетса генератором партии.
  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = random(i + 1);
      final swap = list[i];
      list[i] = list[j];
      list[j] = swap;
    }
  }

  /// [count] случайных элементов без повторов, в порядке выбора.
  List<T> pick<T>(List<T> from, int count) {
    final pool = [...from];
    return [for (var i = 0; i < count && pool.isNotEmpty; i++) pool.removeAt(random(pool.length))];
  }

  /// Новый экземпляр созданной карты (Приманка, Берсерк).
  CardInstance create(CardId card) => CardInstance(CardInstanceId(draft.nextInstanceId++), card);

  /// Берёт до [count] верхних карт колоды в руку.
  void draw(Seat seat, int count) {
    final player = this.player(seat);
    final drawn = [for (var i = 0; i < count && player.deck.isNotEmpty; i++) player.deck.removeAt(0)];
    if (drawn.isEmpty) return;
    player.hand.addAll(drawn);
    emit(CardsDrawn(seat, List.unmodifiable(drawn)));
  }

  /// Карта уходит в отбой хозяина; созданная карта вместо этого выходит из игры (раздел 1.2).
  void discard(Seat owner, CardInstance card) {
    if (unit(card)?.isCreated ?? false) {
      emit(CardLeftGame(card));
    } else {
      player(owner).discard.add(card);
      emit(CardDiscarded(owner, card));
    }
  }
}
