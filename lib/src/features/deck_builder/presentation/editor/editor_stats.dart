import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/diamond_marker.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_state.dart';

/// Пять счётчиков колоды (макет 8): всего, отряды `N/мин`, особые `N/макс`, сила, герои.
///
/// Счётчик, нарушающий правило, красный. Числа правил берутся из конфигурации, а не из вёрстки.
class EditorStats extends StatelessWidget {
  /// Создаёт счётчики для состояния [state].
  const EditorStats({super.key, required this.state});

  /// Состояние конструктора.
  final DeckEditorReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = state.stats;
    final rules = state.rules.gameRules;
    return Row(
      spacing: 5,
      children: [
        _Stat(label: l10n.editorStatTotal, value: '${stats.total}'),
        _Stat(
          label: l10n.editorStatUnits,
          value: '${stats.units}/${rules.minUnitCards}',
          bad: state.tooFewUnits,
        ),
        _Stat(
          label: l10n.editorStatSpecials,
          value: '${stats.specials}/${rules.maxSpecialCards}',
          bad: state.tooManySpecials,
        ),
        _Stat(label: l10n.editorStatPower, value: '${stats.power}'),
        _Stat(label: l10n.editorStatHeroes, value: '${stats.heroes}'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.bad = false});

  final String label;
  final String value;
  final bool bad;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: label,
      value: value,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bad ? GwentColors.errorSurface : GwentColors.rowSurface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: bad ? GwentColors.debuff : GwentColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 7, 0, 6),
          child: Column(
            spacing: 4,
            children: [
              Text(
                value,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  height: 1,
                  color: bad ? GwentColors.errorText : GwentColors.goldHighlight,
                  fontFeatures: GwentText.numbers,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  height: 1,
                  color: bad ? GwentColors.errorText : GwentColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Строка подсказки под счётчиками: что исправить в колоде или причина отказа в добавлении карты.
///
/// Отказ показывается на время, потом снова видна подсказка по колоде. В живой области экрана: диктор зачитывает
/// каждое новое сообщение.
class EditorHint extends StatelessWidget {
  /// Создаёт подсказку для состояния [state].
  const EditorHint({super.key, required this.state});

  /// Состояние конструктора.
  final DeckEditorReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rules = state.rules.gameRules;
    final message = state.message;
    final (text, bad) = switch (message) {
      EditorMessage(:final refusal, :final max) => (
        switch (refusal) {
          AddRefusal.allCopiesInDeck => l10n.editorMsgAllCopies,
          AddRefusal.heroLimit => l10n.editorMsgHero,
          AddRefusal.specialLimit => l10n.editorMsgSpecial(max),
        },
        true,
      ),
      null when state.leader == null => (l10n.editorHintPickLeader, true),
      null when state.tooFewUnits => (l10n.editorHintNeedUnits(rules.minUnitCards - state.stats.units), true),
      null when state.tooManySpecials => (
        l10n.editorHintTooManySpecials(rules.maxSpecialCards, state.stats.specials - rules.maxSpecialCards),
        true,
      ),
      null => (l10n.editorHintValid, false),
    };
    final color = bad ? GwentColors.errorText : GwentColors.gold;
    return Semantics(
      liveRegion: true,
      container: true,
      child: SizedBox(
        height: 30,
        child: Row(
          spacing: 7,
          children: [
            DiamondMarker(size: 8, color: bad ? GwentColors.debuff : GwentColors.gold),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  fontSize: 15,
                  height: 1.1,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
