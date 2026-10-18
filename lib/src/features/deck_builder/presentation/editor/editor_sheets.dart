import 'package:flutter/material.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_detail.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/info_panel.dart';
import 'package:gwent/src/core/presentation/components/screen_labels.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/domain/faction_info.dart';

// Листы и просмотр карты конструктора колоды и списка колод (макет 8).

Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(22, 0, 22, 22 + MediaQuery.viewPaddingOf(context).bottom),
    child: builder(context),
  ),
);

/// Лист «Удалить колоду?» (макет 8, «Удаление с подтверждением»). `true`, если игрок подтвердил.
Future<bool> showDeleteDeckSheet(BuildContext context, String deckName) async {
  final confirmed = await _showSheet<bool>(context, (context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        ScreenTitle(l10n.deckDeleteTitle, size: 26, color: GwentColors.goldHighlight),
        Text(
          l10n.deckDeleteBody(deckName),
          style: const TextStyle(
            fontFamily: GwentText.alegreya,
            fontSize: 17,
            height: 1.35,
            color: GwentColors.textPrimary,
          ),
        ),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: GwentButton(
                label: l10n.dialogCancel,
                style: GwentButtonStyle.secondary,
                fontSize: 21,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            Expanded(
              child: GwentButton(
                label: l10n.deckDeleteConfirm,
                style: GwentButtonStyle.danger,
                fontSize: 21,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  });
  return confirmed ?? false;
}

/// Лист «Смена фракции» (макет 8): предупреждает, сколько карт прежней фракции уйдёт из колоды. `true`, если игрок
/// подтвердил смену.
Future<bool> showFactionChangeSheet(
  BuildContext context, {
  required String fromName,
  required FactionInfo to,
  required int removed,
}) async {
  final confirmed = await _showSheet<bool>(context, (context) {
    final l10n = context.l10n;
    final look = GwentFaction.fromKey(to.key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Row(
          spacing: 12,
          children: [
            if (look.crest case final crest?) GwentIconView(crest, size: 44),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 5,
                children: [
                  Eyebrow(l10n.editorFactionEyebrow, size: 12),
                  ScreenTitle(to.name, size: 26, color: GwentColors.goldHighlight),
                ],
              ),
            ),
          ],
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: GwentColors.errorSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: GwentColors.debuff),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(
                  l10n.editorFactionRemoved(fromName, removed),
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    height: 1.25,
                    color: GwentColors.errorText,
                  ),
                ),
                Text(
                  l10n.editorFactionKept,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontSize: 15,
                    height: 1.35,
                    color: GwentColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: GwentButton(
                label: l10n.dialogCancel,
                style: GwentButtonStyle.secondary,
                fontSize: 21,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            Expanded(
              child: GwentButton(
                label: l10n.editorFactionChange,
                fontSize: 21,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  });
  return confirmed ?? false;
}

/// Лист «Выбор лидера» (макет 8): карты лидеров фракции, способность выбранного и «Подтвердить лидера».
/// Возвращает UUID выбранного лидера или `null`, если лист закрыт без подтверждения.
Future<String?> showLeaderSheet(
  BuildContext context, {
  required FactionInfo faction,
  required String? selectedId,
  required CardFace Function(String leaderId) faceOf,
}) => _showSheet<String>(
  context,
  (context) => _LeaderSheet(faction: faction, selectedId: selectedId, faceOf: faceOf),
);

class _LeaderSheet extends StatefulWidget {
  const _LeaderSheet({required this.faction, required this.selectedId, required this.faceOf});

  final FactionInfo faction;
  final String? selectedId;
  final CardFace Function(String leaderId) faceOf;

  @override
  State<_LeaderSheet> createState() => _LeaderSheetState();
}

class _LeaderSheetState extends State<_LeaderSheet> {
  late String? _picked = widget.faction.leader(widget.selectedId ?? '')?.id ?? widget.faction.leaders.firstOrNull?.id;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final picked = _picked == null ? null : widget.faction.leader(_picked!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 5,
          children: [
            Eyebrow(widget.faction.name, size: 12),
            ScreenTitle(l10n.leaderSelectTitle, size: 26, color: GwentColors.goldHighlight),
          ],
        ),
        Center(
          child: Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              for (final leader in widget.faction.leaders)
                Semantics(
                  button: true,
                  selected: leader.id == _picked,
                  label: leader.name,
                  onTap: () => setState(() => _picked = leader.id),
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _picked = leader.id),
                    child: GwentCard(
                      face: widget.faceOf(leader.id),
                      size: CardSize.grid,
                      highlight: leader.id == _picked ? CardHighlight.selected : CardHighlight.normal,
                    ),
                  ),
                ),
            ],
          ),
        ),
        InfoPanel(
          minHeight: 84,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              InfoPanelLabel(l10n.leaderSelectAbility),
              SizedBox(
                width: double.infinity,
                child: Text(
                  picked?.ability ?? '',
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontSize: 16,
                    height: 1.35,
                    color: GwentColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: GwentButton(
            label: l10n.leaderSelectConfirm,
            onPressed: picked != null && picked.available ? () => Navigator.of(context).pop(picked.id) : null,
          ),
        ),
      ],
    );
  }
}

/// Просмотр карты по долгому нажатию (макет 8, «Долгое нажатие · полный просмотр»): карта, описание, строка
/// «фракция · в колоде N из M» и кнопки [actionLabel] (добавить или убрать) и «Закрыть».
///
/// [onAction] вызывается после закрытия просмотра.
Future<void> showDeckCardPreview(
  BuildContext context, {
  required CardDetail detail,
  required String meta,
  required String actionLabel,
  required VoidCallback? onAction,
}) async {
  final act = await showGeneralDialog<bool>(
    context: context,
    barrierColor: GwentColors.scrimDetail,
    barrierDismissible: true,
    barrierLabel: context.l10n.fieldClose,
    pageBuilder: (context, _, _) =>
        _CardPreview(detail: detail, meta: meta, actionLabel: actionLabel, canAct: onAction != null),
    transitionBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
  if (act ?? false) onAction?.call();
}

class _CardPreview extends StatelessWidget {
  const _CardPreview({required this.detail, required this.meta, required this.actionLabel, required this.canAct});

  final CardDetail detail;
  final String meta;
  final String actionLabel;
  final bool canAct;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final description = detail.quote ?? detail.abilities.firstOrNull?.description;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
        child: Column(
          spacing: 14,
          children: [
            Expanded(
              child: FittedBox(
                child: GwentCard(face: detail.face, size: CardSize.full),
              ),
            ),
            if (description != null)
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                  height: 1.3,
                  color: GwentColors.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
            Text(
              meta,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: GwentText.alegreya,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: GwentColors.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: GwentButton(
                label: actionLabel,
                fontSize: 21,
                onPressed: canAct ? () => Navigator.of(context).pop(true) : null,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: GwentButton(
                label: l10n.fieldClose,
                style: GwentButtonStyle.secondary,
                height: 50,
                fontSize: 21,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
