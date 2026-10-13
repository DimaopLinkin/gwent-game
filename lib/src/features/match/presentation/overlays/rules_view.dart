import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent_engine/gwent_engine.dart' show Faction;

/// Справочник правил (макет 5, раздел 5): пергамент с разделами «Цель», «Ряды», «Погода», «Способности» и «Фракции».
///
/// Открывается из меню паузы, «назад» возвращает в меню. Иконки те же, что на карточках; у фракций вместо золотого
/// диска герб, названия фракций берутся из пакета контента.
class RulesView extends StatelessWidget {
  /// Создаёт справочник; [onBack] возвращает в меню паузы.
  const RulesView({super.key, required this.roster, required this.onBack});

  /// Участники партии: из их контента берутся названия фракций.
  final MatchRoster roster;

  /// Назад.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = FieldContent(content: roster.content, l10n: l10n);
    final sections = <_Section>[
      _Section(l10n.rulesGoalTitle, text: l10n.rulesGoalText),
      _Section(
        l10n.rulesRowsTitle,
        text: l10n.rulesRowsText,
        items: [
          _Item.icon(GwentIcon.rowMelee, l10n.rulesRowMeleeName, l10n.rulesRowMeleeText),
          _Item.icon(GwentIcon.rowRanged, l10n.rulesRowRangedName, l10n.rulesRowRangedText),
          _Item.icon(GwentIcon.rowSiege, l10n.rulesRowSiegeName, l10n.rulesRowSiegeText),
          _Item.icon(GwentIcon.rowAgile, l10n.rulesRowAgileName, l10n.rulesRowAgileText),
        ],
      ),
      _Section(
        l10n.rulesWeatherTitle,
        text: l10n.rulesWeatherText,
        items: [
          _Item.icon(GwentIcon.weatherFrost, l10n.rulesWeatherFrostName, l10n.rulesWeatherFrostText),
          _Item.icon(GwentIcon.weatherFog, l10n.rulesWeatherFogName, l10n.rulesWeatherFogText),
          _Item.icon(GwentIcon.weatherRain, l10n.rulesWeatherRainName, l10n.rulesWeatherRainText),
          _Item.icon(GwentIcon.weatherSkelligeStorm, l10n.rulesWeatherStormName, l10n.rulesWeatherStormText),
          _Item.icon(GwentIcon.weatherClear, l10n.rulesWeatherClearName, l10n.rulesWeatherClearText),
        ],
      ),
      _Section(
        l10n.rulesAbilitiesTitle,
        items: [
          _Item.icon(GwentIcon.abilityTightBond, l10n.rulesAbilityBondName, l10n.rulesAbilityBondText),
          _Item.icon(GwentIcon.abilityMoraleBoost, l10n.rulesAbilityMoraleName, l10n.rulesAbilityMoraleText),
          _Item.icon(GwentIcon.abilityMedic, l10n.rulesAbilityMedicName, l10n.rulesAbilityMedicText),
          _Item.icon(GwentIcon.abilitySpy, l10n.rulesAbilitySpyName, l10n.rulesAbilitySpyText),
          _Item.icon(GwentIcon.abilityBerserk, l10n.rulesAbilityBerserkName, l10n.rulesAbilityBerserkText),
          _Item.icon(GwentIcon.abilityMardroeme, l10n.rulesAbilityMardroemeName, l10n.rulesAbilityMardroemeText),
          _Item.icon(GwentIcon.abilityScorch, l10n.rulesAbilityScorchName, l10n.rulesAbilityScorchText),
          _Item.icon(GwentIcon.abilityTwin, l10n.rulesAbilityTwinName, l10n.rulesAbilityTwinText),
          _Item.icon(GwentIcon.abilityAvenger, l10n.rulesAbilityAvengerName, l10n.rulesAbilityAvengerText),
          _Item.icon(GwentIcon.abilityCommanderHorn, l10n.rulesAbilityHornName, l10n.rulesAbilityHornText),
          _Item.icon(GwentIcon.specialDecoy, l10n.rulesAbilityDecoyName, l10n.rulesAbilityDecoyText),
          _Item.icon(GwentIcon.iconCrownLeading, l10n.rulesAbilityHeroName, l10n.rulesAbilityHeroText),
          _Item.icon(GwentIcon.iconLeader, l10n.rulesAbilityLeaderName, l10n.rulesAbilityLeaderText),
        ],
      ),
      _Section(
        l10n.rulesFactionsTitle,
        text: l10n.rulesFactionsText,
        items: [
          _Item.crest(content, Faction.northernRealms, l10n.rulesFactionNorthernRealms),
          _Item.crest(content, Faction.nilfgaard, l10n.rulesFactionNilfgaard),
          _Item.crest(content, Faction.monsters, l10n.rulesFactionMonsters),
          _Item.crest(content, Faction.scoiatael, l10n.rulesFactionScoiatael),
          _Item.crest(content, Faction.skellige, l10n.rulesFactionSkellige),
        ],
      ),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF0F0C09)),
      child: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B1612), GwentColors.bg],
              ),
              border: Border(bottom: BorderSide(color: GwentColors.brass, width: 1.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                spacing: 14,
                children: [
                  _BackButton(label: l10n.rulesBackSemantics, onPressed: onBack),
                  Text(
                    l10n.rulesTitle,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: GwentText.cormorant,
                      fontWeight: FontWeight.w700,
                      fontSize: 34,
                      height: 1,
                      color: GwentColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [GwentColors.parchmentLight, GwentColors.parchmentShade],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 24,
                  children: [for (final section in sections) _SectionView(section: section)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section {
  const _Section(this.title, {this.text, this.items = const []});

  final String title;
  final String? text;
  final List<_Item> items;
}

class _Item {
  const _Item({required this.name, required this.text, this.icon, this.crest});

  factory _Item.icon(GwentIcon icon, String name, String text) => _Item(name: name, text: text, icon: icon);

  factory _Item.crest(FieldContent content, Faction faction, String text) =>
      _Item(name: content.factionName(faction), text: text, crest: content.faction(faction).crest);

  final String name;
  final String text;
  final GwentIcon? icon;
  final GwentIcon? crest;
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final _Section section;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Row(
        spacing: 12,
        children: [
          Text(
            section.title,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 25,
              height: 1,
              letterSpacing: 25 * 0.03,
              color: GwentColors.onParchment,
            ),
          ),
          const Expanded(
            child: SizedBox(
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [GwentColors.brass, Color(0x008C6A3F)])),
              ),
            ),
          ),
        ],
      ),
      if (section.text case final text?)
        Text(
          text,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: GwentText.alegreya,
            fontSize: 15.5,
            height: 1.45,
            color: GwentColors.onParchment,
          ),
        ),
      for (final item in section.items) _ItemView(item: item),
    ],
  );
}

class _ItemView extends StatelessWidget {
  const _ItemView({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    final crest = item.crest;
    final icon = item.icon;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        SizedBox.square(
          dimension: 34,
          child: crest != null
              ? GwentIconView(crest, size: 34)
              : DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.2, -0.36),
                      radius: 0.9,
                      colors: [Color(0xFFD3B06A), GwentColors.brassLight, GwentColors.brassDark],
                      stops: [0, 0.58, 1],
                    ),
                    boxShadow: [BoxShadow(color: GwentColors.brassDeep, spreadRadius: 1)],
                  ),
                  child: Center(
                    child: icon == null
                        ? null
                        : GwentIconView(icon, size: 20, color: GwentColors.onGold, cutColor: GwentColors.brassCut),
                  ),
                ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                item.name,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  height: 1.2,
                  color: GwentColors.onParchment,
                ),
              ),
              Text(
                item.text,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontSize: 14.5,
                  height: 1.4,
                  color: Color(0xFF3E2F20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onPressed,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 0.75,
                colors: [GwentColors.surfaceWarm, GwentColors.pressed],
              ),
              boxShadow: [BoxShadow(color: GwentColors.brass, spreadRadius: 1)],
            ),
            child: CustomPaint(painter: _ChevronPainter()),
          ),
        ),
      ),
    ),
  );
}

class _ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final path = Path()
      ..moveTo(c.dx + 2.5, c.dy - 5.5)
      ..lineTo(c.dx - 3, c.dy)
      ..lineTo(c.dx + 2.5, c.dy + 5.5);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = GwentColors.textPrimary,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => false;
}
