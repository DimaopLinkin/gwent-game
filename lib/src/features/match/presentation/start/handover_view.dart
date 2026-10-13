import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match/presentation/start/start_parts.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;

/// Передача телефона в hot-seat (макет 4, экран 6): рука закрыта рубашками, крупное имя того, кому передать.
///
/// Рука на этом экране всегда рубашками вверх: игрок видит свои карты только после «Я готов». Подпись под именем
/// говорит, зачем передаётся телефон ([kind]): пересдача, выбор первого игрока, первый ход или ход.
class MatchHandoverView extends StatelessWidget {
  /// Создаёт экран передачи телефона игроку [next].
  const MatchHandoverView({
    super.key,
    required this.next,
    required this.kind,
    required this.roster,
    required this.onReady,
  });

  /// Кто берёт телефон.
  final Seat next;

  /// Зачем передаётся телефон.
  final HandoverKind kind;

  /// Участники партии.
  final MatchRoster roster;

  /// Игрок взял телефон.
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = FieldContent(content: roster.content, l10n: l10n);
    final player = roster.player(next);
    final faction = content.faction(player.faction);
    final name = roster.name(next, l10n);
    final subtitle = switch (kind) {
      HandoverKind.firstPlayerChoice => l10n.matchHandoverFirstPlayerChoice,
      HandoverKind.redraw => l10n.matchHandoverRedraw,
      HandoverKind.firstMove => l10n.matchHandoverFirstMove(name),
      HandoverKind.turn => l10n.matchHandoverTurn(name),
    };
    return StartBackdrop(
      centerGlow: faction.glow,
      base: const Color(0xFF0B0907),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          children: [
            const SizedBox(height: 28),
            ExcludeSemantics(
              child: SizedBox(
                width: 300,
                height: 230,
                child: Stack(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Positioned(
                        left: 111.5,
                        top: 70,
                        child: Transform.rotate(
                          angle: (i - 2) * 9 * math.pi / 180,
                          alignment: const Alignment(0, 1.4),
                          child: GwentCard(
                            face: CardBackFace(faction: faction),
                            size: CardSize.hand,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    l10n.matchHandoverTitle,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: 'Cormorant SC',
                      fontWeight: FontWeight.w600,
                      fontSize: 24,
                      height: 1,
                      letterSpacing: 24 * 0.12,
                      color: GwentColors.textSecondary,
                    ),
                  ),
                  StartTitle(name, size: 60, color: GwentColors.goldHighlight, align: TextAlign.center),
                  FactionLine(faction: faction, name: content.factionName(player.faction), size: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 290),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: StartBody(subtitle),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: GwentButton(label: l10n.matchHandoverReady, height: 60, fontSize: 24, onPressed: onReady),
            ),
          ],
        ),
      ),
    );
  }
}
