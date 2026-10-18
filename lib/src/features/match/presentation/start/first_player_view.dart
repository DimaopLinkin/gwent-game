import 'package:flutter/widgets.dart' hide Intent;
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_labels.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/start/start_parts.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Row;

/// Выбор первого игрока (макет 4, экран 3): игрок Скоя'таэлей сам решает, кто начнёт партию.
///
/// Кнопки «Я» и «Противник» отдают выбор движку. Пока решает соперник (против бота или по сети), кнопок нет:
/// «Противник решает» и пульсирующее «Ожидание выбора…». В hot-seat кнопки относятся к тому, кто держит телефон.
class MatchFirstPlayerView extends StatelessWidget {
  /// Создаёт экран по проекции [view].
  const MatchFirstPlayerView({super.key, required this.view, required this.roster, required this.onIntent});

  /// Проекция партии.
  final PlayerView view;

  /// Участники партии.
  final MatchRoster roster;

  /// Действие игрока.
  final ValueChanged<Intent> onIntent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final choice = view.choice;
    final waiting = choice == null;
    final hotSeat = roster.hotSeat;
    final name = roster.name(view.viewer, l10n);
    final scoiatael = l10n.matchFirstPlayerFaction;
    return StartBackdrop(
      centerGlow: GwentFaction.scoiatael.color.withValues(alpha: 0.24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 16,
                children: [
                  const GwentIconView(GwentIcon.crestScoiatael, size: 112),
                  Eyebrow(hotSeat ? l10n.matchFirstPlayerEyebrowHot(name) : scoiatael, size: 14),
                  ScreenTitle(
                    waiting ? l10n.matchFirstPlayerOpponentDecides : l10n.matchFirstPlayerTitle,
                    size: 44,
                    align: TextAlign.center,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: StartBody(
                      waiting
                          ? l10n.matchFirstPlayerSubtitleWaiting
                          : hotSeat
                          ? l10n.matchFirstPlayerSubtitleHot(name)
                          : l10n.matchFirstPlayerSubtitle,
                      size: 16,
                      color: GwentColors.textTertiary,
                    ),
                  ),
                  if (waiting) const _Pulse(),
                ],
              ),
            ),
            if (choice != null)
              Row(
                spacing: 12,
                children: [
                  for (final option in choice.options)
                    if (option is SeatOption)
                      Expanded(
                        child: GwentButton(
                          label: option.seat == view.viewer ? l10n.matchFirstPlayerMe : l10n.matchFirstPlayerOpponent,
                          height: 64,
                          fontSize: 26,
                          onPressed: () => onIntent(ChooseOption(option)),
                        ),
                      ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// «Ожидание выбора…»: пульсирует, при «уменьшить движение» горит ровно.
class _Pulse extends StatefulWidget {
  const _Pulse();

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.55, end: 1.0).animate(_controller),
    child: StartBody(
      context.l10n.matchFirstPlayerWaitingChoice,
      color: GwentColors.goldHighlight,
      italic: true,
    ),
  );
}
