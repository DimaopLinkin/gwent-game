import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_screen.dart';

/// Конструктор колоды в режиме лобби (макет 8, вход из лобби; макет 9, экран 4c): плашка «соперник ждёт» над шапкой,
/// внизу «Готово, в лобби» и «Отмена».
///
/// Колода сохраняется, даже если нарушает правила: в лобби она будет выбрана, а «Готов» откроется после правки.
/// Ждёт `DeckEditorCubit` выше по дереву.
class LobbyBuilderScreen extends StatelessWidget {
  /// Создаёт экран; [onSaved] получает идентификатор сохранённой колоды, [onCancel] возвращает в лобби без неё.
  const LobbyBuilderScreen({super.key, required this.onSaved, required this.onCancel});

  /// Колода сохранена.
  final ValueChanged<String> onSaved;

  /// Игрок вернулся в лобби, ничего не сохранив.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DeckEditorScreen(
      onExit: onCancel,
      onSaved: onSaved,
      banner: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GwentColors.goldSurface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: GwentColors.brass),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              l10n.netBuilderBanner,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.alegreya,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: GwentColors.goldHighlight,
              ),
            ),
          ),
        ),
      ),
      actionsBuilder: (context, state) => Row(
        spacing: 10,
        children: [
          Expanded(
            flex: 9,
            child: GwentButton(
              label: l10n.netBuilderCancel,
              style: GwentButtonStyle.secondary,
              fontSize: 20,
              solid: true,
              onPressed: onCancel,
            ),
          ),
          Expanded(
            flex: 11,
            child: GwentButton(
              label: l10n.netBuilderDone,
              fontSize: 19,
              maxLines: 2,
              onPressed: state.saving || state.leader == null ? null : context.read<DeckEditorCubit>().save,
            ),
          ),
        ],
      ),
    );
  }
}
