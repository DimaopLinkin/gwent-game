import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_state.dart';

/// Нижние кнопки конструктора, открытого из меню (макет 8): «Сохранить» или, пока колода нарушает правила,
/// «Сохранить как черновик» рядом с погасшей «Сохранить».
///
/// Колоду без лидера сохранить нельзя совсем: у сохранённой колоды лидер есть всегда.
class EditorActions extends StatelessWidget {
  /// Создаёт кнопки для состояния [state]; [onSave] сохраняет колоду.
  const EditorActions({super.key, required this.state, required this.onSave});

  /// Состояние конструктора.
  final DeckEditorReady state;

  /// Игрок нажал сохранение.
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final idle = !state.saving;
    final canSave = idle && state.isValid;
    if (state.isValid) {
      return SizedBox(
        width: double.infinity,
        child: GwentButton(label: l10n.editorSave, onPressed: canSave ? onSave : null),
      );
    }
    return Row(
      spacing: 10,
      children: [
        Expanded(
          flex: 11,
          child: GwentButton(
            label: l10n.editorSaveDraft,
            style: GwentButtonStyle.secondary,
            fontSize: 16,
            maxLines: 2,
            solid: true,
            onPressed: idle && state.leader != null ? onSave : null,
          ),
        ),
        Expanded(
          flex: 9,
          child: GwentButton(label: l10n.editorSave, fontSize: 20, onPressed: canSave ? onSave : null),
        ),
      ],
    );
  }
}
