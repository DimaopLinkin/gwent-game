import 'dart:async';

import 'package:flutter/widgets.dart' hide Intent;
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_detail_view.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/start/start_parts.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Row;

/// Пересдача перед первым раундом (макет 4, экран 4): десять карт тремя колонками, нажатие меняет карту.
///
/// Вверху счётчик «Можно заменить: N» с ромбами по числу замен; заменённая карта уходит в колоду, приходит новая.
/// Удержание карты открывает полный просмотр. «Готово» завершает пересдачу. Когда замен не осталось, карты
/// тускнеют, но «Готово» остаётся.
class MatchRedrawView extends StatefulWidget {
  /// Создаёт экран по проекции [view].
  const MatchRedrawView({super.key, required this.view, required this.roster, required this.onIntent});

  /// Проекция партии.
  final PlayerView view;

  /// Участники партии.
  final MatchRoster roster;

  /// Действие игрока.
  final ValueChanged<Intent> onIntent;

  @override
  State<MatchRedrawView> createState() => _MatchRedrawViewState();
}

class _MatchRedrawViewState extends State<MatchRedrawView> {
  FieldContent? _content;
  AppLocalizations? _l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = context.l10n;
    if (_content == null || !identical(_l10n, l10n)) {
      _l10n = l10n;
      _content = FieldContent(content: widget.roster.content, l10n: l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = widget.view;
    final roster = widget.roster;
    final content = _content!;
    final me = view.me;
    final left = me.redrawsLeft ?? 0;
    final limit = roster.content.rules.redrawLimit;
    final factionName = content.factionName(me.faction);
    final hand = me.hand ?? const <CardInstance>[];
    final rows = [
      for (var i = 0; i < hand.length; i += 3) hand.sublist(i, i + 3 > hand.length ? hand.length : i + 3),
    ];
    return StartBackdrop(
      child: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B1612), GwentColors.bg],
              ),
              border: Border(bottom: BorderSide(color: GwentColors.brass, width: 1.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Eyebrow(
                    roster.hotSeat
                        ? l10n.matchRedrawEyebrowHot(roster.name(view.viewer, l10n), factionName)
                        : factionName,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    spacing: 10,
                    children: [
                      Flexible(child: StartTitle(l10n.matchRedrawTitle, size: 34)),
                      _LeftPill(left: left, limit: limit, label: l10n.matchRedrawLeft(left)),
                    ],
                  ),
                  StartBody(l10n.matchRedrawHint, size: 14, align: TextAlign.start),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 56),
                  child: Column(
                    spacing: 10,
                    children: [
                      for (final row in rows)
                        Row(
                          mainAxisAlignment: row.length == 3 ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
                          spacing: row.length == 3 ? 0 : 10,
                          children: [
                            for (final card in row)
                              GwentCard(
                                key: ValueKey(card.id),
                                face: content.face(card),
                                size: CardSize.grid,
                                highlight: left > 0 ? CardHighlight.normal : CardHighlight.disabled,
                                onTap: left > 0 ? () => widget.onIntent(RedrawCard(card.id)) : null,
                                onLongPress: () => unawaited(showCardDetail(context, content.detail(card))),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 44,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x000F0C09), Color(0xFF0F0C09)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              spacing: 8,
              children: [
                StartBody(l10n.matchRedrawHoldHint, size: 12.5, italic: true),
                SizedBox(
                  width: double.infinity,
                  child: GwentButton(
                    label: l10n.matchRedrawDone,
                    onPressed: () => widget.onIntent(const FinishRedraw()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Счётчик замен: ромбы по числу замен (золотые — доступные) и подпись.
class _LeftPill extends StatelessWidget {
  const _LeftPill({required this.left, required this.limit, required this.label});

  final int left;
  final int limit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final on = left > 0;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: GwentColors.bg,
          boxShadow: on
              ? const [
                  BoxShadow(color: GwentColors.gold, spreadRadius: 1.5),
                  BoxShadow(color: Color(0x59C8A35B), blurRadius: 12),
                ]
              : const [BoxShadow(color: GwentColors.line, spreadRadius: 1)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            for (var i = 0; i < limit; i++)
              Transform.rotate(
                angle: 0.7853981633974483,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: i < left
                        ? const LinearGradient(colors: [GwentColors.goldHighlight, GwentColors.brassLight])
                        : null,
                    color: i < left ? null : GwentColors.socket,
                    border: Border.all(color: i < left ? GwentColors.bg : GwentColors.line),
                  ),
                ),
              ),
            Text(
              label,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: GwentText.alegreya,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1,
                color: on ? GwentColors.goldHighlight : GwentColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ожидание, пока соперник закончит пересдачу (макет 4, экран 5): рубашки его руки, герб, число моих замен.
class MatchRedrawWaitView extends StatelessWidget {
  /// Создаёт экран по проекции [view].
  const MatchRedrawWaitView({super.key, required this.view, required this.roster});

  /// Проекция партии.
  final PlayerView view;

  /// Участники партии.
  final MatchRoster roster;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = FieldContent(content: roster.content, l10n: l10n);
    final opponent = content.faction(view.opponent.faction);
    final replaced = roster.content.rules.redrawLimit - (view.me.redrawsLeft ?? 0);
    final crest = opponent.crest;
    return StartBackdrop(
      centerGlow: opponent.glow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 26,
            children: [
              if (crest != null) GwentIconView(crest, size: 64),
              SizedBox(
                width: 5 * 52 + 4 * 8,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < view.opponent.handCount; i++)
                      GwentCard(
                        face: CardBackFace(faction: opponent),
                        size: CardSize.row,
                      ),
                  ],
                ),
              ),
              Column(
                spacing: 8,
                children: [
                  StartTitle(l10n.matchRedrawOpponentBusy, size: 32, align: TextAlign.center),
                  StartBody(l10n.matchRedrawReplaced(replaced)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
