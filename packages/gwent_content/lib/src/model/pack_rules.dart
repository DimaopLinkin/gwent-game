import 'package:gwent_content/src/model/ability.dart';
import 'package:gwent_content/src/model/effect_resolver.dart';
import 'package:gwent_content/src/model/fraction.dart';
import 'package:gwent_content/src/model/game_rules.dart';
import 'package:gwent_content/src/model/leader_card.dart';
import 'package:gwent_content/src/model/raw_params.dart';
import 'package:gwent_content/src/model/resolved_effect.dart';
import 'package:gwent_content/src/model/special_card.dart';
import 'package:gwent_content/src/model/squad_card.dart';
import 'package:gwent_content/src/model/zone.dart';

/// Таблицы правил пакета (`pack.json`): всё, что входит в `content_hash`.
///
/// Списки хранятся в порядке из файла; для поиска есть словари по UUID. Если в таблице повторяется UUID,
/// словарь хранит последнюю запись, а валидатор такой пакет отклоняет.
final class PackRules {
  /// Создаёт таблицы правил.
  PackRules({
    required this.gameRules,
    required List<Zone> zones,
    required List<Fraction> fractions,
    required List<Ability> fractionAbilities,
    required List<Ability> squadAbilities,
    required List<Ability> specialAbilities,
    required List<Ability> leaderAbilities,
    required List<SquadCard> squadCards,
    required List<SpecialCard> specialCards,
    required List<LeaderCard> leaderCards,
  }) : zones = List.unmodifiable(zones),
       fractions = List.unmodifiable(fractions),
       fractionAbilities = List.unmodifiable(fractionAbilities),
       squadAbilities = List.unmodifiable(squadAbilities),
       specialAbilities = List.unmodifiable(specialAbilities),
       leaderAbilities = List.unmodifiable(leaderAbilities),
       squadCards = List.unmodifiable(squadCards),
       specialCards = List.unmodifiable(specialCards),
       leaderCards = List.unmodifiable(leaderCards);

  /// Числовые параметры партии и колоды.
  final GameRules gameRules;

  /// Зоны карт отрядов.
  final List<Zone> zones;

  /// Фракции.
  final List<Fraction> fractions;

  /// Перки фракций.
  final List<Ability> fractionAbilities;

  /// Способности карт отрядов.
  final List<Ability> squadAbilities;

  /// Способности специальных карт.
  final List<Ability> specialAbilities;

  /// Способности лидеров.
  final List<Ability> leaderAbilities;

  /// Карты отрядов.
  final List<SquadCard> squadCards;

  /// Специальные карты.
  final List<SpecialCard> specialCards;

  /// Карты лидеров.
  final List<LeaderCard> leaderCards;

  /// Зоны по UUID.
  late final Map<String, Zone> zonesById = {for (final zone in zones) zone.id: zone};

  /// Фракции по UUID.
  late final Map<String, Fraction> fractionsById = {for (final fraction in fractions) fraction.id: fraction};

  /// Перки фракций по UUID.
  late final Map<String, Ability> fractionAbilitiesById = _byId(fractionAbilities);

  /// Способности карт отрядов по UUID.
  late final Map<String, Ability> squadAbilitiesById = _byId(squadAbilities);

  /// Способности специальных карт по UUID.
  late final Map<String, Ability> specialAbilitiesById = _byId(specialAbilities);

  /// Способности лидеров по UUID.
  late final Map<String, Ability> leaderAbilitiesById = _byId(leaderAbilities);

  /// Карты отрядов по UUID.
  late final Map<String, SquadCard> squadCardsById = {for (final card in squadCards) card.id: card};

  /// Специальные карты по UUID.
  late final Map<String, SpecialCard> specialCardsById = {for (final card in specialCards) card.id: card};

  /// Карты лидеров по UUID.
  late final Map<String, LeaderCard> leaderCardsById = {for (final card in leaderCards) card.id: card};

  /// Эффект карты отряда или `null`, если способности у неё нет.
  ResolvedEffect? effectOfSquadCard(SquadCard card) {
    final abilityId = card.abilityId;
    return abilityId == null ? null : _resolve(squadAbilitiesById, abilityId, card.abilityParams, card.id);
  }

  /// Эффект специальной карты.
  ResolvedEffect effectOfSpecialCard(SpecialCard card) =>
      _resolve(specialAbilitiesById, card.abilityId, card.abilityParams, card.id);

  /// Эффект карты лидера.
  ResolvedEffect effectOfLeaderCard(LeaderCard card) =>
      _resolve(leaderAbilitiesById, card.abilityId, card.abilityParams, card.id);

  /// Перк фракции или `null`, если перка нет.
  ResolvedEffect? perkOfFraction(Fraction fraction) {
    final abilityId = fraction.abilityId;
    return abilityId == null ? null : _resolve(fractionAbilitiesById, abilityId, const {}, fraction.id);
  }

  /// Эффект проверенного пакета; на непроверенном бросает [StateError].
  ResolvedEffect _resolve(Map<String, Ability> abilities, String abilityId, RawParams cardParams, String ownerId) {
    final ability = abilities[abilityId] ?? (throw StateError('у $ownerId нет способности $abilityId'));
    return resolveEffect(
          ability,
          cardParams,
          path: ownerId,
          onIssue: (path, code, message) => throw StateError('$path: $code, $message'),
        ) ??
        (throw StateError('параметры эффекта $ownerId не прошли проверку'));
  }

  static Map<String, Ability> _byId(List<Ability> abilities) => {
    for (final ability in abilities) ability.id: ability,
  };
}
