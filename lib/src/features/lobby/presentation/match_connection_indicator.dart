import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_state.dart';

/// Связь с соперником в полосе игрока (макет 9, экран 5): значок Wi-Fi, а при проблемах янтарная или красная метка.
///
/// Занимает только место, которое отдала полоса: связь в норме — один значок, без подписи; «Нестабильно», «Пауза» и
/// «Нет связи · 1:59» — значок с подписью. Если подпись не влезает в отданную ширину, остаётся короткая («1:59») или
/// один значок, цвет которого говорит о состоянии. Читается скринридером полным текстом. Ждёт `MatchConnectionCubit`
/// выше по дереву.
class MatchConnectionIndicator extends StatelessWidget {
  /// Создаёт индикатор.
  const MatchConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<MatchConnectionCubit, MatchConnectionState>(
    builder: (context, state) => _Indicator(state: state),
  );
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.state});

  final MatchConnectionState state;

  /// Значок в метке и один.
  static const double _iconSize = 13;

  /// Поля метки по горизонтали и толщина рамки.
  static const double _padding = 7;
  static const double _border = 1;
  static const double _gap = 4;

  static const TextStyle _style = TextStyle(
    fontFamily: GwentText.alegreya,
    fontWeight: FontWeight.w700,
    fontSize: 12,
    height: 1,
    letterSpacing: 0.3,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lost = state.lost;
    final warn = state.unstable || state.away;
    final icon = lost ? GwentIcon.iconWifiOff : (state.away ? GwentIcon.iconPause : GwentIcon.iconWifi);
    final tone = lost ? GwentColors.errorText : (warn ? GwentColors.amber : GwentColors.textSecondary);
    final ring = lost ? GwentColors.dangerRing : GwentColors.amberRing;
    final full = lost
        ? '${l10n.netLinkLost} · ${state.leftClock}'
        : state.away
        ? l10n.netAwayTitle
        : state.unstable
        ? l10n.netLinkUnstable
        : l10n.netLinkOk;
    // Подписи от длинной к короткой; у связи в норме подписи нет.
    final labels = lost
        ? [full, state.leftClock]
        : state.away
        ? [l10n.netLinkAway]
        : state.unstable
        ? [l10n.netLinkUnstable]
        : const <String>[];
    return Semantics(
      label: full,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final direction = Directionality.of(context);
          for (final label in labels) {
            final width = _labelWidth(label, direction);
            if (width <= constraints.maxWidth) return _Pill(icon: icon, tone: tone, ring: ring, label: label);
          }
          return constraints.maxWidth < _iconSize
              ? const SizedBox.shrink()
              : GwentIconView(icon, size: _iconSize, color: tone);
        },
      ),
    );
  }

  /// Ширина метки с подписью [label]: значок, подпись и поля с рамкой.
  static double _labelWidth(String label, TextDirection direction) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _style),
      textDirection: direction,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return 2 * (_padding + _border) + _iconSize + _gap + width;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.tone, required this.ring, required this.label});

  final GwentIcon icon;
  final Color tone;
  final Color ring;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: ring),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: _Indicator._padding, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: _Indicator._gap,
        children: [
          GwentIconView(icon, size: _Indicator._iconSize, color: tone),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            textScaler: TextScaler.noScaling,
            style: _Indicator._style.copyWith(color: tone),
          ),
        ],
      ),
    ),
  );
}
