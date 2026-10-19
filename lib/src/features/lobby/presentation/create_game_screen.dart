import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_state.dart';
import 'package:gwent/src/features/lobby/presentation/network_notice.dart';

/// Создание партии (макет 9, экран 2a): название партии и кнопка «Создать». Колоду здесь не выбирают.
///
/// Когда партия создана, экран сообщает [onCreated]: ожидание соперника показывает комната.
class CreateGameScreen extends StatelessWidget {
  /// Создаёт экран.
  const CreateGameScreen({super.key, required this.onCreated, required this.onBack});

  /// Партия создана и объявлена в сети.
  final VoidCallback onCreated;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: BlocConsumer<CreateGameCubit, CreateGameState>(
        listenWhen: (previous, current) => current is CreateGameCreated,
        listener: (context, state) => onCreated(),
        builder: (context, state) => Column(
          children: [
            ScreenHeader(title: l10n.netCreateTitle, titleSize: 32, onBack: onBack),
            Expanded(
              child: switch (state) {
                CreateGameLoading() || CreateGameCreating() || CreateGameCreated() => const GameLoader(),
                CreateGameForm(:final initialName) => _Form(
                  initialName: initialName,
                  onSubmit: context.read<CreateGameCubit>().create,
                ),
                CreateGameFailed(:final result, :final name) => _Failed(
                  result: result,
                  onRetry: () => context.read<CreateGameCubit>().create(name),
                  onBack: onBack,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.result, required this.onRetry, required this.onBack});

  final NetworkOpenResult result;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notice = noticeOfResult(l10n, result);
    return NetworkNotice(
      title: notice.title,
      text: notice.text,
      actions: [
        (label: l10n.netNoticeRetry, style: GwentButtonStyle.primary, onPressed: onRetry),
        (label: l10n.netNoticeBack, style: GwentButtonStyle.secondary, onPressed: onBack),
      ],
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.initialName, required this.onSubmit});

  final String initialName;
  final ValueChanged<String> onSubmit;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  static const int _maxLength = 20;

  late final TextEditingController _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const textStyle = TextStyle(
      fontFamily: GwentText.alegreya,
      fontWeight: FontWeight.w500,
      fontSize: 18,
      height: 1,
      color: GwentColors.textPrimary,
    );
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: color, width: width),
    );
    const noteStyle = TextStyle(fontFamily: GwentText.alegreya, fontSize: 14, height: 1.3, color: Color(0xFF8A7D64));
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(l10n.netCreateNameLabel, style: textStyle.copyWith(height: 1.2)),
          Semantics(
            label: l10n.netCreateNameLabel,
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _controller,
                inputFormatters: [LengthLimitingTextInputFormatter(_maxLength)],
                textInputAction: TextInputAction.done,
                onSubmitted: widget.onSubmit,
                style: textStyle,
                cursorColor: GwentColors.gold,
                decoration: InputDecoration(
                  hintText: l10n.netCreateNameHint,
                  hintStyle: textStyle.copyWith(color: GwentColors.muted),
                  filled: true,
                  fillColor: const Color(0xFF0B0907),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  enabledBorder: border(GwentColors.muted),
                  focusedBorder: border(GwentColors.gold, 1.5),
                ),
              ),
            ),
          ),
          Text(l10n.netCreateNameNote, style: noteStyle),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l10n.netCreateDeckNote, style: noteStyle),
          ),
          const Spacer(),
          GwentButton(label: l10n.netCreateSubmit, onPressed: () => widget.onSubmit(_controller.text)),
        ],
      ),
    );
  }
}
