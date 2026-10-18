import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/card/leader_name.dart';
import 'package:gwent/src/core/presentation/components/diamond_marker.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/status_tag.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_issue_text.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent/src/features/match/presentation/setup/setup_parts.dart';

/// Выбор колоды перед матчем (макет 7): список колод выбранной фракции, «Изменить» и «Играть».
///
/// Колода, которая не проходит правила, помечена «Колода не готова», причина показана под списком, а «Играть»
/// погашена. На строке стоит лидер, выбранный на предыдущем шаге: он пойдёт в партию вместо лидера колоды.
class DeckSelectView extends StatelessWidget {
  /// Создаёт экран.
  const DeckSelectView({
    super.key,
    required this.eyebrow,
    required this.choices,
    required this.selectedId,
    required this.faction,
    required this.leaderName,
    required this.leaderFace,
    required this.issueText,
    required this.playLabel,
    required this.onSelect,
    required this.onEdit,
    required this.onPlay,
    required this.onBack,
    this.busy = false,
  });

  /// Надпись над заголовком.
  final String eyebrow;

  /// Колоды фракции.
  final List<DeckChoice> choices;

  /// Идентификатор выбранной колоды.
  final String? selectedId;

  /// Выбранная фракция: название и цвет метки.
  final ({String name, GwentFaction look}) faction;

  /// Полное имя выбранного лидера.
  final String leaderName;

  /// Лицо карты выбранного лидера для мини-карты в строках.
  final CardFace leaderFace;

  /// Объяснение, почему колода не годится.
  final DeckIssueText issueText;

  /// Подпись главной кнопки: «Играть» или «Дальше» (когда после этого выбирает второй игрок).
  final String playLabel;

  /// Игрок выбрал колоду с идентификатором `deckId`.
  final ValueChanged<String> onSelect;

  /// Игрок хочет изменить колоду с идентификатором `deckId`.
  final ValueChanged<String> onEdit;

  /// Игрок подтвердил выбранную колоду.
  final VoidCallback onPlay;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  /// Идёт сохранение выбора: кнопки не принимают нажатий.
  final bool busy;

  DeckChoice? get _selected {
    for (final choice in choices) {
      if (choice.deck.id == selectedId) return choice;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = _selected;
    final ready = selected?.ready ?? false;
    final reason = selected == null ? null : issueText.firstOf(selected.issues);
    return SetupScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
        child: Column(
          children: [
            SetupHeader(
              eyebrow: eyebrow,
              title: l10n.deckSelectTitle,
              titleSize: 34,
              onBack: onBack,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 2),
                itemCount: choices.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _DeckRow(
                  choice: choices[i],
                  selected: choices[i].deck.id == selectedId,
                  faction: faction,
                  leaderName: leaderName,
                  leaderFace: leaderFace,
                  onTap: () => onSelect(choices[i].deck.id),
                ),
              ),
            ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    reason,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      height: 1.3,
                      color: GwentColors.errorText,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 10),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: GwentButton(
                    label: l10n.deckSelectEdit,
                    // Негодную колоду нужно чинить: «Изменить» становится главным действием.
                    style: selected != null && !ready ? GwentButtonStyle.primary : GwentButtonStyle.secondary,
                    solid: true,
                    onPressed: selected == null || busy ? null : () => onEdit(selected.deck.id),
                  ),
                ),
                Expanded(
                  child: GwentButton(label: playLabel, onPressed: ready && !busy ? onPlay : null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckRow extends StatelessWidget {
  const _DeckRow({
    required this.choice,
    required this.selected,
    required this.faction,
    required this.leaderName,
    required this.leaderFace,
    required this.onTap,
  });

  final DeckChoice choice;
  final bool selected;
  final ({String name, GwentFaction look}) faction;
  final String leaderName;
  final CardFace leaderFace;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        spacing: 12,
        children: [
          GwentCard(face: leaderFace, size: CardSize.row),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  choice.deck.name,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    height: 1.05,
                    color: GwentColors.textPrimary,
                  ),
                ),
                Row(
                  spacing: 6,
                  children: [
                    DiamondMarker(size: 8, color: faction.look.accent),
                    Expanded(child: _Line(faction.name, color: GwentColors.textTertiary)),
                  ],
                ),
                _Line(shortLeaderName(leaderName), color: GwentColors.textSecondary, italic: true),
                _Line(l10n.deckSelectCards(choice.deck.cardCount), color: GwentColors.textTertiary),
              ],
            ),
          ),
          SizedBox(
            width: 78,
            height: 74,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (choice.ready)
                  StatusTag(l10n.deckSelectReady, background: GwentColors.goldSurface, color: GwentColors.gold)
                else
                  StatusTag(
                    l10n.deckSelectNotReady,
                    background: GwentColors.errorSurface,
                    color: GwentColors.errorText,
                    ring: GwentColors.debuff,
                  ),
                if (selected)
                  const DiamondMarker(size: 12, color: GwentColors.goldHighlight, glow: Color(0xB3C8A35B))
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: choice.deck.name,
      value:
          '${choice.ready ? l10n.deckSelectReady : l10n.deckSelectNotReady}, '
          '${l10n.deckSelectCards(choice.deck.cardCount)}, ${shortLeaderName(leaderName)}',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? GwentColors.rowSelected : GwentColors.rowSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? GwentColors.gold : GwentColors.line, width: selected ? 1.5 : 1),
          ),
          child: selected
              ? Padding(
                  padding: const EdgeInsets.all(2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: GwentColors.brass),
                    ),
                    child: content,
                  ),
                )
              : content,
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text, {required this.color, this.italic = false});

  final String text;
  final Color color;
  final bool italic;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textScaler: TextScaler.noScaling,
    style: TextStyle(
      fontFamily: GwentText.alegreya,
      fontWeight: FontWeight.w500,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      fontSize: 14,
      height: 1.2,
      color: color,
    ),
  );
}
