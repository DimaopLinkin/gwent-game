import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_content_mapper.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/card/parts/dashed_rrect_painter.dart';
import 'package:gwent/src/core/presentation/components/chevron_button.dart';
import 'package:gwent/src/core/presentation/components/faction_medallion.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_state.dart';

/// Шапка конструктора (макет 8): фракция со стрелками смены, название колоды и лидер.
///
/// Тап по лидеру открывает выбор лидера. У колоды без лидера вместо карты красная пунктирная рамка с «+».
class EditorHeader extends StatelessWidget {
  /// Создаёт шапку для состояния [state].
  const EditorHeader({
    super.key,
    required this.state,
    required this.mapper,
    required this.onPrevFaction,
    required this.onNextFaction,
    required this.onRename,
    required this.onPickLeader,
  });

  /// Состояние конструктора.
  final DeckEditorReady state;

  /// Сопоставление карт пакета с видом карты.
  final CardContentMapper mapper;

  /// Игрок нажал стрелку влево.
  final VoidCallback onPrevFaction;

  /// Игрок нажал стрелку вправо.
  final VoidCallback onNextFaction;

  /// Игрок изменил название колоды.
  final ValueChanged<String> onRename;

  /// Игрок нажал на лидера.
  final VoidCallback onPickLeader;

  /// Ширина колонки фракции и названия, ниже которой герб убирается, чтобы поместилось название.
  static const double _narrowWidth = 250;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final look = GwentFaction.fromKey(state.faction.key);
    final leaderCard = switch (state.draft.leaderId) {
      final id? => state.rules.pack.rules.leaderCardsById[id],
      null => null,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < _narrowWidth;
              return Column(
                spacing: 8,
                children: [
                  Row(
                    children: [
                      ChevronButton(label: l10n.factionSelectPrevious, onPressed: state.saving ? null : onPrevFaction),
                      Expanded(
                        // Герб и название стоят одной группой по центру между стрелками, а не растягиваются на всю ширину.
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 8,
                            children: [
                              // На узком экране названию нужнее место, чем гербу: герб виден и на карте лидера.
                              if (!narrow) FactionMedallion(faction: look, size: 38, crestSize: 26),
                              Flexible(
                                child: Text(
                                  state.faction.name,
                                  // Длинное название переносится на вторую строку, обе строки по центру, без многоточия.
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  textWidthBasis: TextWidthBasis.longestLine,
                                  textScaler: TextScaler.noScaling,
                                  style: const TextStyle(
                                    fontFamily: GwentText.cormorant,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 19,
                                    height: 1.05,
                                    color: GwentColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ChevronButton(
                        label: l10n.factionSelectNext,
                        forward: true,
                        onPressed: state.saving ? null : onNextFaction,
                      ),
                    ],
                  ),
                  NameField(initialName: state.draft.name, onChanged: onRename),
                ],
              );
            },
          ),
        ),
        _LeaderSlot(
          face: leaderCard == null ? null : mapper.leader(leaderCard).face,
          onTap: state.saving ? null : onPickLeader,
        ),
      ],
    );
  }
}

/// Поле названия колоды: хранит набранный текст у себя и сообщает о каждой правке.
class NameField extends StatefulWidget {
  /// Создаёт поле с начальным названием [initialName].
  const NameField({super.key, required this.initialName, required this.onChanged});

  /// Название при открытии конструктора.
  final String initialName;

  /// Правка названия.
  final ValueChanged<String> onChanged;

  /// Предел длины названия.
  static const int maxLength = 40;

  @override
  State<NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<NameField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: GwentColors.rowSurface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: GwentColors.line),
    ),
    child: SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          inputFormatters: [LengthLimitingTextInputFormatter(NameField.maxLength)],
          textInputAction: TextInputAction.done,
          cursorColor: GwentColors.goldHighlight,
          style: const TextStyle(
            fontFamily: GwentText.cormorant,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 18 * 0.03,
            color: GwentColors.textPrimary,
          ),
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: context.l10n.editorNameLabel,
            hintStyle: const TextStyle(color: GwentColors.muted),
          ),
        ),
      ),
    ),
  );
}

class _LeaderSlot extends StatelessWidget {
  const _LeaderSlot({required this.face, required this.onTap});

  final CardFace? face;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final face = this.face;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: l10n.editorPickLeader,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 58,
          child: Column(
            spacing: 4,
            children: [
              if (face != null)
                GwentCard(face: face, size: CardSize.row)
              else
                const SizedBox(
                  width: 52,
                  height: 74,
                  child: CustomPaint(
                    painter: DashedRRectPainter(color: GwentColors.debuff, strokeWidth: 1.5, radius: 3),
                    child: Center(
                      child: Text(
                        '+',
                        style: TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                          height: 1,
                          color: GwentColors.errorText,
                        ),
                      ),
                    ),
                  ),
                ),
              Text(
                l10n.editorLeaderLabel.toUpperCase(),
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 1,
                  letterSpacing: 11 * 0.1,
                  color: face == null ? GwentColors.errorText : GwentColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
