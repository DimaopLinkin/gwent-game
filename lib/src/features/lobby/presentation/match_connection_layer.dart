import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_state.dart';

/// Связь поверх поля сетевой партии (макет 9, экраны 5 и 6): точка связи сверху и окно обрыва с отсчётом.
///
/// Ждёт `MatchConnectionCubit` выше по дереву. Пока связь потеряна, окно закрывает поле; «Ждать» убирает его, и
/// остаётся точка с оставшимся временем. [onEnd] заканчивает матч: хост засчитывает себе поражение, гость уходит.
class MatchConnectionLayer extends StatelessWidget {
  /// Создаёт слой.
  const MatchConnectionLayer({super.key, required this.onEnd});

  /// Игрок решил не ждать и закончить матч.
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) => BlocBuilder<MatchConnectionCubit, MatchConnectionState>(
    builder: (context, state) => Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: MediaQuery.paddingOf(context).top + 7,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(child: _Chip(state: state)),
          ),
        ),
        if (state.lost && !state.dismissed)
          _LostWindow(state: state, onWait: context.read<MatchConnectionCubit>().wait, onEnd: onEnd),
      ],
    ),
  );
}

String _clock(Duration time) {
  final seconds = time.inSeconds < 0 ? 0 : time.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _Chip extends StatelessWidget {
  const _Chip({required this.state});

  final MatchConnectionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lost = state.lost;
    final tone = lost ? GwentColors.debuff : GwentColors.gold;
    final label = lost ? '${l10n.netLinkLost} · ${_clock(state.left)}' : l10n.netLinkOk;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xEB0E0B09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: lost ? GwentColors.dangerRing : GwentColors.brass),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone,
                  boxShadow: [BoxShadow(color: tone, blurRadius: 6)],
                ),
                child: const SizedBox.square(dimension: 8),
              ),
              Text(
                label,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  letterSpacing: 0.5,
                  color: lost ? GwentColors.errorText : GwentColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LostWindow extends StatelessWidget {
  const _LostWindow({required this.state, required this.onWait, required this.onEnd});

  final MatchConnectionState state;
  final VoidCallback onWait;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final host = state.isHost;
    final tone = host ? GwentColors.debuff : GwentColors.gold;
    final total = context.read<MatchConnectionCubit>().total;
    final fraction = total == Duration.zero ? 0.0 : (state.left.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: ColoredBox(
        color: const Color(0xD60A0806),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [GwentColors.panel, GwentColors.bg],
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tone),
                boxShadow: const [BoxShadow(color: Color(0xB3000000), blurRadius: 50, offset: Offset(0, 20))],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Center(
                      child: SizedBox.square(
                        dimension: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (!host) const GwentSpinner(size: 64),
                            GwentIconView(GwentIcon.iconWifi, size: 28, color: tone),
                          ],
                        ),
                      ),
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        host ? l10n.netLostTitle : l10n.netReconnectTitle,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 29,
                          height: 1.05,
                          color: GwentColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      host ? l10n.netLostHostText : l10n.netReconnectText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: GwentText.alegreya,
                        fontWeight: FontWeight.w500,
                        fontSize: 16.5,
                        height: 1.35,
                        color: GwentColors.textTertiary,
                      ),
                    ),
                    Semantics(
                      liveRegion: false,
                      label: _clock(state.left),
                      excludeSemantics: true,
                      child: Text(
                        _clock(state.left),
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 54,
                          height: 1,
                          letterSpacing: 2,
                          fontFeatures: const [FontFeature.liningFigures(), FontFeature.tabularFigures()],
                          color: tone,
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 3,
                        child: Stack(
                          children: [
                            const Positioned.fill(child: ColoredBox(color: GwentColors.surfaceRaised)),
                            FractionallySizedBox(
                              widthFactor: fraction,
                              child: ColoredBox(color: tone, child: const SizedBox.expand()),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (host) GwentButton(label: l10n.netLostWait, fontSize: 21, onPressed: onWait),
                    GwentButton(
                      label: l10n.netLostEnd,
                      style: GwentButtonStyle.danger,
                      fontSize: 21,
                      onPressed: onEnd,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
