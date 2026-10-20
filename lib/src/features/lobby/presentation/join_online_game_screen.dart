import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';
import 'package:gwent/src/features/lobby/presentation/join_online_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/join_online_game_state.dart';
import 'package:gwent/src/features/lobby/presentation/network_notice.dart';

/// Ввод кода комнаты для игры через интернет: гость набирает или вставляет код, который ему продиктовал хост.
///
/// Ответы сервиса (комната не найдена, занята, закрыта, слишком много попыток, сервис недоступен) показываются под
/// полем, код при этом остаётся: его можно поправить или повторить попытку. Когда гость вошёл, экран сообщает
/// [onJoined]: ожидание решения хоста показывает комната лобби.
class JoinOnlineGameScreen extends StatelessWidget {
  /// Создаёт экран.
  const JoinOnlineGameScreen({super.key, required this.onJoined, required this.onBack});

  /// Гость вошёл в комнату.
  final VoidCallback onJoined;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: BlocConsumer<JoinOnlineGameCubit, JoinOnlineGameState>(
        listenWhen: (previous, current) => current is JoinOnlineGameJoined,
        listener: (context, state) => onJoined(),
        builder: (context, state) => Padding(
          // Экран без `Scaffold`: клавиатуру он обходит сам, иначе она закроет кнопку.
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            children: [
              ScreenHeader(title: l10n.netOnlineJoinTitle, titleSize: 32, onBack: onBack),
              Expanded(child: _Form(state: state)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.state});

  final JoinOnlineGameState state;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => unawaited(context.read<JoinOnlineGameCubit>().join(_controller.text));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;
    final busy = state is! JoinOnlineGameForm;
    final form = state is JoinOnlineGameForm ? state : null;
    final problem = form != null && form.badCode ? l10n.netOnlineBadCode : null;
    final failure = form?.failure;
    final notice = failure == null ? null : noticeOfResult(l10n, failure, link: NoticeLink.onlineGuest);
    const noteStyle = TextStyle(fontFamily: GwentText.alegreya, fontSize: 14, height: 1.3, color: Color(0xFF8A7D64));
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: color, width: width),
    );
    const codeStyle = TextStyle(
      fontFamily: GwentText.cormorant,
      fontWeight: FontWeight.w700,
      fontSize: 38,
      height: 1,
      letterSpacing: 6,
      fontFeatures: GwentText.numbers,
      color: GwentColors.goldHighlight,
    );
    return Column(
      children: [
        Expanded(
          // Поле и ответ сервиса прокручиваются, кнопка остаётся на виду над клавиатурой даже на низком экране.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Text(
                  l10n.netOnlineCodeLabel,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                    height: 1.2,
                    color: GwentColors.textPrimary,
                  ),
                ),
                Semantics(
                  label: l10n.netOnlineCodeLabel,
                  textField: true,
                  child: TextField(
                    controller: _controller,
                    enabled: !busy,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.go,
                    inputFormatters: [_CodeFormatter()],
                    onChanged: (_) {
                      setState(() {});
                      context.read<JoinOnlineGameCubit>().edited();
                    },
                    onSubmitted: (_) => _submit(),
                    style: codeStyle,
                    cursorColor: GwentColors.gold,
                    decoration: InputDecoration(
                      hintText: l10n.netOnlineCodeHint,
                      hintStyle: codeStyle.copyWith(color: GwentColors.muted),
                      filled: true,
                      fillColor: const Color(0xFF0B0907),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      enabledBorder: border(
                        problem != null || notice != null ? GwentColors.errorText : GwentColors.muted,
                      ),
                      disabledBorder: border(GwentColors.panelLine),
                      focusedBorder: border(GwentColors.gold, 1.5),
                    ),
                  ),
                ),
                Text(l10n.netOnlineCodeNote, style: noteStyle),
                if (problem != null) _Problem(text: problem),
                if (notice != null) _Problem(title: notice.title, text: notice.text),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: SizedBox(
            width: double.infinity,
            child: GwentButton(
              label: busy ? l10n.netOnlineJoining : l10n.netOnlineJoin,
              onPressed: busy || _controller.text.length < RoomCode.length ? null : _submit,
            ),
          ),
        ),
      ],
    );
  }
}

/// Ответ на попытку входа под полем кода: красная плашка с заголовком и пояснением.
class _Problem extends StatelessWidget {
  const _Problem({required this.text, this.title});

  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GwentColors.errorSurface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: GwentColors.dangerPanelRing),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                if (title != null)
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: GwentText.cormorant,
                      fontWeight: FontWeight.w700,
                      fontSize: 21,
                      height: 1.1,
                      color: GwentColors.errorText,
                    ),
                  ),
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontSize: 15,
                      height: 1.35,
                      color: GwentColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Оставляет в поле только буквы и цифры, приводит их к заглавным и режет по длине кода. Вставка «abc-def»
/// превращается в «ABCDEF». Знаки вне алфавита кода (0, 1, I, O) остаются в поле: гость увидит, что с ними не так.
class _CodeFormatter extends TextInputFormatter {
  static final RegExp _foreign = RegExp('[^A-Za-z0-9]');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final cleaned = newValue.text.replaceAll(_foreign, '').toUpperCase();
    final text = cleaned.length > RoomCode.length ? cleaned.substring(0, RoomCode.length) : cleaned;
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
