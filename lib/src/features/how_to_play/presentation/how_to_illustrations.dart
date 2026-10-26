import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_content_mapper.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/how_to_play/domain/how_to_examples.dart';
import 'package:gwent/src/features/how_to_play/domain/how_to_topic.dart';
import 'package:gwent/src/features/how_to_play/presentation/how_to_widgets.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent_engine/gwent_engine.dart' show Faction;

/// Иллюстрация темы справочника на настоящих картах пакета; `null`, если у темы её нет.
Widget? howToIllustration(HowToTopic topic, GameContent content, AppLocalizations l10n) {
  final mapper = CardContentMapper(pack: content.pack, l10n: l10n);
  return switch (topic) {
    HowToTopic.goal || HowToTopic.handAndDeck || HowToTopic.turnAndPass => null,
    HowToTopic.rowsAndPower => _RowsField(mapper: mapper),
    HowToTopic.weather => _ExampleList([
      for (final weather in HowToWeather.values)
        _example(
          mapper,
          weather.cardId,
          _weatherIcon(weather),
          _weatherName(l10n, weather),
          _weatherText(l10n, weather),
        ),
    ]),
    HowToTopic.abilities => _ExampleList([
      for (final ability in HowToAbility.values)
        _example(
          mapper,
          ability.cardId,
          _abilityIcon(ability),
          _abilityName(l10n, ability),
          _abilityText(l10n, ability),
        ),
    ]),
    HowToTopic.specials => _ExampleList([
      for (final special in HowToSpecial.values)
        _example(
          mapper,
          special.cardId,
          _specialIcon(special),
          _specialName(l10n, special),
          _specialText(l10n, special),
        ),
    ]),
    HowToTopic.leadersAndFactions => _Leaders(content: content, mapper: mapper, l10n: l10n),
  };
}

_Example _example(CardContentMapper mapper, String cardId, GwentIcon icon, String name, String text) =>
    _Example(face: mapper.byId(cardId)?.face, icon: icon, name: name, text: text);

GwentIcon _weatherIcon(HowToWeather weather) => switch (weather) {
  HowToWeather.frost => GwentIcon.weatherFrost,
  HowToWeather.fog => GwentIcon.weatherFog,
  HowToWeather.rain => GwentIcon.weatherRain,
  HowToWeather.storm => GwentIcon.weatherSkelligeStorm,
  HowToWeather.clear => GwentIcon.weatherClear,
};

String _weatherName(AppLocalizations l10n, HowToWeather weather) => switch (weather) {
  HowToWeather.frost => l10n.howToWeatherFrostName,
  HowToWeather.fog => l10n.howToWeatherFogName,
  HowToWeather.rain => l10n.howToWeatherRainName,
  HowToWeather.storm => l10n.howToWeatherStormName,
  HowToWeather.clear => l10n.howToWeatherClearName,
};

String _weatherText(AppLocalizations l10n, HowToWeather weather) => switch (weather) {
  HowToWeather.frost => l10n.howToWeatherFrostText,
  HowToWeather.fog => l10n.howToWeatherFogText,
  HowToWeather.rain => l10n.howToWeatherRainText,
  HowToWeather.storm => l10n.howToWeatherStormText,
  HowToWeather.clear => l10n.howToWeatherClearText,
};

GwentIcon _abilityIcon(HowToAbility ability) => switch (ability) {
  HowToAbility.tightBond => GwentIcon.abilityTightBond,
  HowToAbility.moraleBoost => GwentIcon.abilityMoraleBoost,
  HowToAbility.medic => GwentIcon.abilityMedic,
  HowToAbility.spy => GwentIcon.abilitySpy,
  HowToAbility.berserk => GwentIcon.abilityBerserk,
  HowToAbility.muster => GwentIcon.abilityTwin,
  HowToAbility.scorch => GwentIcon.abilityScorch,
  HowToAbility.bait => GwentIcon.abilityAvenger,
  HowToAbility.commanderHorn => GwentIcon.abilityCommanderHorn,
  HowToAbility.hero => GwentIcon.iconCrownLeading,
};

String _abilityName(AppLocalizations l10n, HowToAbility ability) => switch (ability) {
  HowToAbility.tightBond => l10n.howToAbilityTightBondName,
  HowToAbility.moraleBoost => l10n.howToAbilityMoraleBoostName,
  HowToAbility.medic => l10n.howToAbilityMedicName,
  HowToAbility.spy => l10n.howToAbilitySpyName,
  HowToAbility.berserk => l10n.howToAbilityBerserkName,
  HowToAbility.muster => l10n.howToAbilityMusterName,
  HowToAbility.scorch => l10n.howToAbilityScorchName,
  HowToAbility.bait => l10n.howToAbilityBaitName,
  HowToAbility.commanderHorn => l10n.howToAbilityCommanderHornName,
  HowToAbility.hero => l10n.howToAbilityHeroName,
};

String _abilityText(AppLocalizations l10n, HowToAbility ability) => switch (ability) {
  HowToAbility.tightBond => l10n.howToAbilityTightBondText,
  HowToAbility.moraleBoost => l10n.howToAbilityMoraleBoostText,
  HowToAbility.medic => l10n.howToAbilityMedicText,
  HowToAbility.spy => l10n.howToAbilitySpyText,
  HowToAbility.berserk => l10n.howToAbilityBerserkText,
  HowToAbility.muster => l10n.howToAbilityMusterText,
  HowToAbility.scorch => l10n.howToAbilityScorchText,
  HowToAbility.bait => l10n.howToAbilityBaitText,
  HowToAbility.commanderHorn => l10n.howToAbilityCommanderHornText,
  HowToAbility.hero => l10n.howToAbilityHeroText,
};

GwentIcon _specialIcon(HowToSpecial special) => switch (special) {
  HowToSpecial.commanderHorn => GwentIcon.abilityCommanderHorn,
  HowToSpecial.decoy => GwentIcon.specialDecoy,
  HowToSpecial.mardroeme => GwentIcon.abilityMardroeme,
  HowToSpecial.scorch => GwentIcon.abilityScorch,
};

String _specialName(AppLocalizations l10n, HowToSpecial special) => switch (special) {
  HowToSpecial.commanderHorn => l10n.howToSpecialCommanderHornName,
  HowToSpecial.decoy => l10n.howToSpecialDecoyName,
  HowToSpecial.mardroeme => l10n.howToSpecialMardroemeName,
  HowToSpecial.scorch => l10n.howToSpecialScorchName,
};

String _specialText(AppLocalizations l10n, HowToSpecial special) => switch (special) {
  HowToSpecial.commanderHorn => l10n.howToSpecialCommanderHornText,
  HowToSpecial.decoy => l10n.howToSpecialDecoyText,
  HowToSpecial.mardroeme => l10n.howToSpecialMardroemeText,
  HowToSpecial.scorch => l10n.howToSpecialScorchText,
};

/// Пример: карта слева, справа иконка, название и одна фраза. Без карты (её нет в пакете) остаётся текст.
class _Example {
  const _Example({required this.face, required this.icon, required this.name, required this.text});

  final CardFace? face;
  final GwentIcon icon;
  final String name;
  final String text;
}

class _ExampleList extends StatelessWidget {
  const _ExampleList(this.examples);

  final List<_Example> examples;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 14,
    children: [for (final example in examples) _ExampleRow(example)],
  );
}

class _ExampleRow extends StatelessWidget {
  const _ExampleRow(this.example);

  final _Example example;

  @override
  Widget build(BuildContext context) {
    final face = example.face;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        if (face != null) GwentCard(face: face, size: CardSize.row),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              Row(
                spacing: 8,
                children: [
                  HowToCoin(example.icon, size: 28),
                  Expanded(
                    child: Text(
                      example.name,
                      style: howToBodyStyle.copyWith(
                        fontWeight: FontWeight.w800,
                        color: GwentColors.goldHighlight,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              Text(example.text, style: howToBodyStyle.copyWith(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Мини-поле: три ряда на настоящих картах с суммой силы каждого ряда и счётом.
class _RowsField extends StatelessWidget {
  const _RowsField({required this.mapper});

  final CardContentMapper mapper;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = [
      (GwentIcon.rowMelee, l10n.howToRowMelee, HowToRowExamples.melee),
      (GwentIcon.rowRanged, l10n.howToRowRanged, HowToRowExamples.ranged),
      (GwentIcon.rowSiege, l10n.howToRowSiege, HowToRowExamples.siege),
    ];
    var total = 0;
    final views = <Widget>[];
    for (final (icon, label, ids) in rows) {
      final faces = [for (final id in ids) ?mapper.byId(id)?.face];
      final sum = faces.whereType<UnitCardFace>().fold(0, (sum, face) => sum + face.basePower);
      total += sum;
      views.add(_FieldRow(icon: icon, label: label, faces: faces, sum: sum));
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GwentColors.rowSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GwentColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          spacing: 10,
          children: [
            ...views,
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                l10n.howToScore(total),
                style: const TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  height: 1,
                  color: GwentColors.goldHighlight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.icon, required this.label, required this.faces, required this.sum});

  final GwentIcon icon;
  final String label;
  final List<CardFace> faces;
  final int sum;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $sum',
    excludeSemantics: true,
    child: Row(
      spacing: 10,
      children: [
        GwentIconView(icon, size: 26),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [for (final face in faces) GwentCard(face: face, size: CardSize.row)],
          ),
        ),
        Text(
          '$sum',
          style: const TextStyle(
            fontFamily: GwentText.alegreya,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            height: 1,
            fontFeatures: GwentText.numbers,
            color: GwentColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

/// Лидер-пример и пять фракций с гербом, названием и перком из пакета.
class _Leaders extends StatelessWidget {
  const _Leaders({required this.content, required this.mapper, required this.l10n});

  final GameContent content;
  final CardContentMapper mapper;
  final AppLocalizations l10n;

  static const List<Faction> _factions = [
    Faction.northernRealms,
    Faction.nilfgaard,
    Faction.monsters,
    Faction.scoiatael,
    Faction.skellige,
  ];

  @override
  Widget build(BuildContext context) {
    final fieldContent = FieldContent(content: content, l10n: l10n);
    final leader = mapper.byId(HowToLeaderExample.cardId)?.face;
    final rules = content.pack.rules;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        if (leader != null)
          Center(
            child: GwentCard(face: leader, size: CardSize.grid),
          ),
        Text(
          l10n.howToFactionsTitle,
          style: const TextStyle(
            fontFamily: GwentText.cormorant,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            height: 1.1,
            color: GwentColors.goldHighlight,
          ),
        ),
        for (final faction in _factions)
          () {
            final style = fieldContent.faction(faction);
            final fraction = rules.fractionsById.values.where((fraction) => fraction.key == style.key).firstOrNull;
            final perk = switch (fraction?.abilityId) {
              final id? when rules.fractionAbilitiesById[id] != null => content.pack.text(
                rules.fractionAbilitiesById[id]!.descriptionKey,
              ),
              _ => l10n.howToFactionPerkMissing,
            };
            return _FactionRow(crest: style.crest, name: fieldContent.factionName(faction), perk: perk);
          }(),
      ],
    );
  }
}

class _FactionRow extends StatelessWidget {
  const _FactionRow({required this.crest, required this.name, required this.perk});

  final GwentIcon? crest;
  final String name;
  final String perk;

  @override
  Widget build(BuildContext context) {
    final crest = this.crest;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        SizedBox.square(dimension: 44, child: crest == null ? null : GwentIconView(crest, size: 44)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(name, style: howToBodyStyle.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
              Text(perk, style: howToBodyStyle.copyWith(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}
