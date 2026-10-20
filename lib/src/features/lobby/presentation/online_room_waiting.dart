import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';
import 'package:gwent/src/features/lobby/presentation/room_code_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/room_code_state.dart';

/// Ожидание соперника у хоста игры через интернет: крупный код комнаты, который можно скопировать или продиктовать.
///
/// Код меняется, когда комната создаётся заново для нового гостя, поэтому экран всегда показывает текущий.
class OnlineRoomWaiting extends StatefulWidget {
  /// Создаёт ожидание; [onCancel] закрывает комнату.
  const OnlineRoomWaiting({super.key, required this.onCancel});

  /// Игрок отменил комнату.
  final VoidCallback onCancel;

  @override
  State<OnlineRoomWaiting> createState() => _OnlineRoomWaitingState();
}

class _OnlineRoomWaitingState extends State<OnlineRoomWaiting> {
  /// Сколько подпись кнопки сообщает, что код скопирован.
  static const Duration _copiedFor = Duration(seconds: 2);

  Timer? _reset;
  bool _copied = false;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy(RoomCode code) async {
    await Clipboard.setData(ClipboardData(text: code.formatted));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(_copiedFor, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<RoomCodeCubit>().state;
    final code = state is RoomCodeReady ? state.code : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 14,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.netWaitTitle,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 30,
                          color: GwentColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: _CodeCard(code: code, failed: state is RoomCodeFailed),
                    ),
                    Text(
                      l10n.netOnlineWaitHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: GwentText.alegreya,
                        fontSize: 16,
                        height: 1.35,
                        color: GwentColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: GwentButton(
              label: _copied ? l10n.netOnlineCodeCopied : l10n.netOnlineCodeCopy,
              fontSize: 21,
              onPressed: code == null ? null : () => unawaited(_copy(code)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: GwentButton(
              label: l10n.dialogCancel,
              style: GwentButtonStyle.secondary,
              fontSize: 21,
              onPressed: widget.onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

/// Код на пергаменте: крупно, одной строкой при любой ширине экрана.
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.failed});

  final RoomCode? code;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = this.code;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GwentColors.parchmentLight, GwentColors.parchmentShade],
        ),
        border: Border.all(color: GwentColors.brass),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 34, offset: Offset(0, 14))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(
              l10n.netOnlineCodeCaption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: GwentText.alegreya,
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: GwentColors.onParchmentSecondary,
              ),
            ),
            if (failed && code == null)
              Text(
                l10n.netOnlineCodeFailed,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontSize: 15,
                  height: 1.35,
                  color: GwentColors.onParchment,
                ),
              )
            else
              Semantics(
                label: code == null ? null : l10n.netOnlineCodeSemantics(code.value.split('').join(' ')),
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      code?.formatted ?? '······',
                      maxLines: 1,
                      softWrap: false,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: GwentText.cormorant,
                        fontWeight: FontWeight.w700,
                        fontSize: 54,
                        height: 1.05,
                        letterSpacing: 5,
                        fontFeatures: GwentText.numbers,
                        color: GwentColors.onParchment,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
