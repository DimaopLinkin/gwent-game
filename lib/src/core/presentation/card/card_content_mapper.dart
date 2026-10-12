import 'package:flutter/painting.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_detail.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_weather.dart';
import 'package:gwent_content/gwent_content.dart';

/// Собирает [CardFace] и [CardDetail] из записей пакета контента: тексты из строк пакета, иконки по эффекту
/// способности, арт по UUID карты из `asset/image/cards/`.
final class CardContentMapper {
  /// Создаёт сопоставитель для пакета [pack] со строками интерфейса [l10n].
  const CardContentMapper({required this.pack, required this.l10n});

  /// Папка артов в ассетах приложения.
  static const String artFolder = 'asset/image/cards';

  /// Пакет контента.
  final ContentPack pack;

  /// Строки интерфейса.
  final AppLocalizations l10n;

  /// Арт карты с UUID [cardId].
  static ImageProvider artOf(String cardId) => AssetImage('$artFolder/$cardId.jpg');

  /// Карта с UUID [cardId] любого типа; `null`, если в пакете её нет.
  CardDetail? byId(String cardId) {
    final rules = pack.rules;
    if (rules.squadCardsById[cardId] case final card?) return squad(card);
    if (rules.specialCardsById[cardId] case final card?) return special(card);
    if (rules.leaderCardsById[cardId] case final card?) return leader(card);
    return null;
  }

  /// Отряд или герой. [power] — текущая сила на столе (по умолчанию базовая), [frosted] — ряд под погодой.
  CardDetail squad(SquadCard card, {int? power, bool frosted = false}) {
    final rules = pack.rules;
    final effect = rules.effectOfSquadCard(card)?.effect;
    final zone = rules.zonesById[card.zoneId];
    final ability = switch (card.abilityId) {
      final abilityId? => rules.squadAbilitiesById[abilityId],
      null => null,
    };
    return CardDetail(
      face: UnitCardFace(
        art: artOf(card.id),
        name: pack.text(card.nameKey),
        faction: _faction(card.fractionId),
        basePower: card.strength,
        power: power,
        row: _rowIcon(zone?.key),
        // Проворство уже видно по иконке ряда, вторая монета его не повторяет.
        ability: effect == null || effect == EffectKey.agile ? null : _abilityIcon(effect),
        isHero: card.isHero,
        frosted: frosted,
      ),
      meta: l10n.cardMetaUnit(
        _factionName(card.fractionId, neutral: l10n.cardFactionNeutral),
        zone == null ? '' : pack.text(zone.nameKey),
        card.isHero ? l10n.cardKindHero : l10n.cardKindUnit,
      ),
      abilities: [
        if (card.isHero)
          CardAbilityLine(
            icon: GwentIcon.iconCrownLeading,
            name: l10n.cardHeroAbilityTitle,
            description: l10n.cardHeroAbilityDescription,
          ),
        if ((ability, effect) case (final ability?, final effect?)) _line(ability, _abilityIcon(effect)),
      ],
      quote: _optionalText(card.descriptionKey),
    );
  }

  /// Особая карта или погода.
  CardDetail special(SpecialCard card) {
    final rules = pack.rules;
    final effect = rules.effectOfSpecialCard(card);
    final ability = rules.specialAbilitiesById[card.abilityId];
    final name = pack.text(card.nameKey);
    final weather = _weather(effect);
    final CardFace face;
    final GwentIcon icon;
    if (weather != null) {
      face = WeatherCardFace(art: artOf(card.id), name: name, weather: weather);
      icon = weather.icon;
    } else {
      icon = _abilityIcon(effect.effect);
      face = SpecialCardFace(art: artOf(card.id), name: name, faction: _faction(card.fractionId), effect: icon);
    }
    return CardDetail(
      face: face,
      meta: l10n.cardMetaSpecial(
        weather == null ? l10n.cardKindSpecial : l10n.cardKindWeather,
        _factionName(card.fractionId, neutral: l10n.cardFactionCommon),
      ),
      abilities: [if (ability != null) _line(ability, icon, fallbackName: name)],
      quote: _optionalText(card.descriptionKey),
    );
  }

  /// Лидер; [abilityUsed] — способность уже применена в этой партии.
  CardDetail leader(LeaderCard card, {bool abilityUsed = false}) {
    final ability = pack.rules.leaderAbilitiesById[card.abilityId];
    final faction = _faction(card.fractionId);
    return CardDetail(
      face: LeaderCardFace(
        art: artOf(card.id),
        name: pack.text(card.nameKey),
        faction: faction,
        abilityUsed: abilityUsed,
      ),
      meta: l10n.cardMetaLeader(
        _factionName(card.fractionId, neutral: l10n.cardFactionNeutral),
        l10n.cardKindLeader,
        abilityUsed ? l10n.cardLeaderStatusUsed : l10n.cardLeaderStatusReady,
      ),
      abilities: [
        if (ability != null)
          CardAbilityLine(
            icon: GwentIcon.iconLeader,
            name: l10n.cardLeaderAbilityTitle,
            description: pack.text(ability.descriptionKey),
          ),
      ],
      quote: _optionalText(card.descriptionKey),
    );
  }

  CardAbilityLine _line(Ability ability, GwentIcon icon, {String? fallbackName}) => CardAbilityLine(
    icon: icon,
    name: switch (ability.nameKey) {
      final key? => pack.text(key),
      null => fallbackName ?? '',
    },
    description: pack.text(ability.descriptionKey),
  );

  GwentFaction _faction(String fractionId) => switch (pack.rules.fractionsById[fractionId]) {
    final fraction? => GwentFaction.fromKey(fraction.key),
    null => GwentFaction.neutral,
  };

  String _factionName(String fractionId, {required String neutral}) => switch (pack.rules.fractionsById[fractionId]) {
    final fraction? when GwentFaction.fromKey(fraction.key) != GwentFaction.neutral => pack.text(fraction.nameKey),
    _ => neutral,
  };

  String? _optionalText(String key) {
    if (key.isEmpty) return null;
    final text = pack.text(key);
    return text.isEmpty || text == key ? null : text;
  }

  static GwentIcon _rowIcon(ZoneKey? zone) => switch (zone) {
    ZoneKey.melee || null => GwentIcon.rowMelee,
    ZoneKey.ranged => GwentIcon.rowRanged,
    ZoneKey.siege => GwentIcon.rowSiege,
    ZoneKey.agile => GwentIcon.rowAgile,
  };

  /// Погода по рядам эффекта: мороз, туман, ливень, шторм Скеллиге (несколько рядов) или ясная погода.
  static GwentWeather? _weather(ResolvedEffect effect) => switch (effect.effect) {
    EffectKey.clearWeather => GwentWeather.clear,
    EffectKey.weather => switch ({...effect.rows('rows')}) {
      final rows when rows.length > 1 => GwentWeather.skelligeStorm,
      final rows when rows.contains(CombatRow.ranged) => GwentWeather.fog,
      final rows when rows.contains(CombatRow.siege) => GwentWeather.rain,
      _ => GwentWeather.frost,
    },
    _ => null,
  };

  static GwentIcon _abilityIcon(EffectKey effect) => switch (effect) {
    EffectKey.spy => GwentIcon.abilitySpy,
    EffectKey.medic => GwentIcon.abilityMedic,
    EffectKey.muster => GwentIcon.abilityTwin,
    EffectKey.tightBond => GwentIcon.abilityTightBond,
    EffectKey.moraleBoost => GwentIcon.abilityMoraleBoost,
    EffectKey.commanderHorn => GwentIcon.abilityCommanderHorn,
    EffectKey.scorchRow || EffectKey.scorch => GwentIcon.abilityScorch,
    EffectKey.bait => GwentIcon.abilityAvenger,
    EffectKey.berserk => GwentIcon.abilityBerserk,
    EffectKey.mardroeme => GwentIcon.abilityMardroeme,
    EffectKey.agile => GwentIcon.rowAgile,
    EffectKey.decoy => GwentIcon.specialDecoy,
    EffectKey.weather || EffectKey.clearWeather => GwentIcon.weatherClear,
    _ => GwentIcon.iconLeader,
  };
}
