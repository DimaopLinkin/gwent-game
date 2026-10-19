import 'dart:math' as math;

import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart'
    show
        CardId,
        ClearWeatherAbility,
        DecoyAbility,
        HornCardAbility,
        MardremCardAbility,
        Rng,
        ScorchAbility,
        SpecialCardDefinition,
        WeatherAbility;

/// Сборка колоды бота под уровень сложности (ADR 0021).
///
/// Бот собирает колоду из той же коллекции, что и игрок (`DeckRules.collectionFor`), по тем же правилам. Каждой карте
/// даётся ключ: оценка карты, умноженная на вкус уровня, плюс случайная добавка. Вкус лёгкого уровня отрицательный
/// (слабые карты идут первыми), нормального нулевой (набор почти случайный), тяжёлого и «НА СМЕРТЬ!» положительный
/// (сильные первыми). Случайная добавка есть на всех уровнях, поэтому колода одного уровня каждый раз другая:
/// уровень задаёт силу набора, а не список карт. Карты берутся по убыванию ключа, пока не наберётся нужное число.
final class BotDeckBuilder {
  /// Создаёт сборщика по правилам [rules].
  BotDeckBuilder(this._rules) : _values = CardValues(_rules.catalog, const GreedyBotSettings());

  final DeckRules _rules;
  final CardValues _values;

  /// Колода фракции [factionId] для бота уровня [difficulty]; случайность даёт [rng].
  ///
  /// Если собранная колода не проходит правила (в пакете не хватает карт), возвращает стартовую колоду фракции.
  Deck build(String factionId, BotDifficulty difficulty, Rng rng) {
    final profile = _Profile.of(difficulty);
    final cards = _rules.collectionFor(factionId);
    final units = cards.where((card) => card.isUnit).toList();
    final specials = cards.where((card) => card.isSpecial).toList();
    final leaders = _rules.factionInfos.firstWhere((faction) => faction.id == factionId).leaders;

    var generator = rng;
    double roll() {
      final (value, next) = generator.nextInt(1000);
      generator = next;
      return value / 1000;
    }

    int between(int low, int high) {
      final (value, next) = generator.nextInt(high - low + 1);
      generator = next;
      return low + value;
    }

    final minUnits = _rules.gameRules.minUnitCards;
    final unitTarget = minUnits + between(0, profile.extraUnits);
    final specialTarget = between(profile.specials.$1, profile.specials.$2).clamp(0, _rules.gameRules.maxSpecialCards);
    final chosen = <String, int>{
      ..._pick(units, _unitValue, profile, roll, unitTarget, exact: false),
      ..._pick(specials, _specialValue, profile, roll, specialTarget, exact: true),
    };
    final leader = leaders[between(0, leaders.length - 1)];

    final deck = Deck(
      id: id,
      name: _rules.factionInfos.firstWhere((faction) => faction.id == factionId).name,
      factionId: factionId,
      leaderId: leader.id,
      cards: chosen,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
    return _rules.check(deck).isEmpty ? deck : _rules.starterDeck(factionId, id: id, updatedAt: deck.updatedAt);
  }

  /// Идентификатор колоды бота: в хранилище её нет.
  static const String id = 'bot-opponent';

  /// Берёт карты по убыванию ключа, пока их не наберётся [target]; карта кладётся всеми копиями, а при [exact]
  /// последняя берётся неполностью, чтобы число карт было ровно [target].
  Map<String, int> _pick(
    List<CollectionCard> cards,
    double Function(CollectionCard card) value,
    _Profile profile,
    double Function() roll,
    int target, {
    required bool exact,
  }) {
    if (cards.isEmpty) return const {};
    final top = cards.map(value).reduce((a, b) => a > b ? a : b);
    final keyed = [
      for (final card in cards)
        (card: card, key: profile.taste * (top == 0 ? 0 : value(card) / top) + profile.noise * roll()),
    ]..sort((a, b) => b.key.compareTo(a.key));
    final picked = <String, int>{};
    var count = 0;
    for (final (:card, key: _) in keyed) {
      if (count >= target) break;
      // Особых карт не больше цели (в колоде их ограниченное число), отрядов набирается не меньше цели.
      final copies = exact ? math.min(card.maxCopies, target - count) : card.maxCopies;
      picked[card.id] = copies;
      count += copies;
    }
    return picked;
  }

  double _unitValue(CollectionCard card) => _values.worth(CardId(card.id)).toDouble();

  /// Грубая ценность особой карты: рог и казнь сильнее всего, погода слабее.
  double _specialValue(CollectionCard card) => switch (_rules.catalog.card(CardId(card.id))) {
    SpecialCardDefinition(:final ability) => switch (ability) {
      HornCardAbility() => 10,
      ScorchAbility() => 9,
      MardremCardAbility() => 8,
      DecoyAbility() => 7,
      WeatherAbility() => 6,
      ClearWeatherAbility() => 4,
    },
    _ => 0,
  };
}

/// Как уровень собирает колоду: вкус, случайная добавка, число лишних отрядов и особых карт.
final class _Profile {
  const _Profile({required this.taste, required this.noise, required this.extraUnits, required this.specials});

  factory _Profile.of(BotDifficulty difficulty) => switch (difficulty) {
    BotDifficulty.easy => const _Profile(taste: -1, noise: 0.5, extraUnits: 0, specials: (0, 3)),
    BotDifficulty.normal => const _Profile(taste: 0, noise: 1, extraUnits: 2, specials: (3, 6)),
    BotDifficulty.hard => const _Profile(taste: 1, noise: 0.5, extraUnits: 2, specials: (5, 8)),
    BotDifficulty.deathMatch => const _Profile(taste: 1, noise: 0.25, extraUnits: 3, specials: (8, 10)),
  };

  /// Во сколько раз оценка карты влияет на ключ; отрицательный — слабые карты первыми.
  final double taste;

  /// Размах случайной добавки к ключу при оценке карты от 0 до 1.
  final double noise;

  /// Сколько отрядов бот может взять сверх минимума.
  final int extraUnits;

  /// Сколько особых карт: от и до.
  final (int, int) specials;
}
