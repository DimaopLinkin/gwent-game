import 'package:gwent_engine/gwent_engine.dart';

/// Намерения хода, которые стоит проверить движком: карты руки во все подходящие ряды и на все цели, затем лидер.
///
/// Рог и Мардрём бот кладёт только в свободные слоты: в занятый движок их тоже принимает, но карта уходит в отбой
/// впустую. Список может содержать недопустимые намерения (например, Чучело на героя): их отсеивает движок.
/// Из одинаковых карт руки берётся первая: их розыгрыш даёт одинаковый результат. Пас сюда не входит.
List<Intent> turnCandidates(PlayerView view, CardCatalog catalog) {
  final me = view.me;
  final ownUnits = [
    for (final row in Row.values)
      for (final card in me.rows[row]!.cards) card.card.id,
  ];
  final seen = <CardId>{};
  return [
    for (final card in me.hand ?? const <CardInstance>[])
      if (me.playable.contains(card.id) && seen.add(card.cardId))
        ...switch (catalog.card(card.cardId)) {
          UnitCardDefinition(:final placement) => [for (final row in placement.rows) PlayCard(card.id, row: row)],
          SpecialCardDefinition(ability: HornCardAbility() || MardremCardAbility()) => [
            for (final row in Row.values)
              if (me.rows[row]!.slot == null) PlayCard(card.id, row: row),
          ],
          SpecialCardDefinition(ability: DecoyAbility()) => [
            for (final target in ownUnits) PlayCard(card.id, target: target),
          ],
          SpecialCardDefinition(ability: WeatherAbility() || ClearWeatherAbility() || ScorchAbility()) => [
            PlayCard(card.id),
          ],
          null => const <Intent>[],
        },
    if (me.leaderAvailable) const UseLeader(),
  ];
}
