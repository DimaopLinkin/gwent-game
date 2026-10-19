import 'dart:math';

import 'package:gwent_ai/src/greedy_bot_settings.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Грубые оценки карт в очках силы. Бот оценивает только свои карты и открытые варианты выбора; по ним же
/// собирается колода бота.
final class CardValues {
  const CardValues(this._catalog, this._settings);

  final CardCatalog _catalog;
  final GreedyBotSettings _settings;

  /// Сколько стоит карта в руке: сила плюс то, что она приносит сверх силы (карты Шпиона, отряд Медика, Двойника).
  /// Шпион стоит не меньше обычной карты: две карты в руку окупают даже сильного Шпиона.
  int worth(CardId id) {
    final weight = _settings.cardWeight;
    return switch (_catalog.card(id)) {
      UnitCardDefinition(:final strength, :final ability) => switch (ability) {
        SpyAbility(:final draw) => max(draw * weight - strength, weight),
        MedicAbility() || MusterAbility() => strength + weight,
        _ => strength,
      },
      SpecialCardDefinition() => weight,
      null => 0,
    };
  }

  /// Сколько очков карта может добавить своей стороне в этом раунде: Шпион не добавляет, погода тоже.
  int points(CardId id) => switch (_catalog.card(id)) {
    UnitCardDefinition(ability: SpyAbility()) => 0,
    UnitCardDefinition(:final strength) => strength,
    SpecialCardDefinition(ability: HornCardAbility() || ScorchAbility()) => _settings.cardWeight,
    SpecialCardDefinition() || null => 0,
  };
}
