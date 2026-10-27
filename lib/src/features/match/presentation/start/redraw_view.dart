import 'dart:async';

import 'package:flutter/widgets.dart' hide Intent;
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_detail_view.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_labels.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent/src/features/match/presentation/start/start_parts.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Row;

/// Пересдача перед первым раундом (макет 4, экран 4): десять карт тремя колонками, нажатие меняет карту.
///
/// Вверху счётчик «Можно заменить: N» с ромбами по числу замен; заменённая карта уходит в колоду, приходит новая.
/// Удержание карты открывает полный просмотр. «Готово» завершает пересдачу. Когда замен не осталось, карты
/// тускнеют, но «Готово» остаётся.
///
/// Карты лежат в порядке руки (`HandOrder`): особые слева, отряды по возрастанию силы, при равной силе по имени.
/// Это порядок показа, номера карт для обмена остаются прежними.
///
/// Замена видна в два шага: старая карта сворачивается на своём месте, затем рука встаёт в новом порядке, и новая
/// карта проявляется на своём отсортированном месте и светится, пока её не заметили. После последней замены экран (`MatchRedrawSettled`) на время остаётся с [settled]: карты и «Готово»
/// недоступны, пришедшая карта на виду, и только потом игрок уходит на ожидание соперника.
class MatchRedrawView extends StatefulWidget {
  /// Создаёт экран по проекции [view].
  const MatchRedrawView({
    super.key,
    required this.view,
    required this.roster,
    required this.onIntent,
    this.settled = false,
    this.style = StageStyle.normal,
  });

  /// Проекция партии.
  final PlayerView view;

  /// Участники партии.
  final MatchRoster roster;

  /// Действие игрока.
  final ValueChanged<Intent> onIntent;

  /// Замены кончились, экран только показывает руку: нажатия не принимаются.
  final bool settled;

  /// Скорость анимаций из настроек.
  final StageStyle style;

  @override
  State<MatchRedrawView> createState() => _MatchRedrawViewState();
}

class _MatchRedrawViewState extends State<MatchRedrawView> {
  static const int _columns = 3;
  static final double _cardWidth = CardSize.grid.metrics.width;

  FieldContent? _content;
  AppLocalizations? _l10n;

  /// Карты, пришедшие при последней замене: светятся, пока их не заметили.
  Set<CardInstanceId> _fresh = const {};
  Timer? _freshTimer;

  /// Рука, какой её видно, пока уходящая карта сворачивается; `null`, когда показывается рука проекции.
  List<CardInstance>? _folding;

  /// Карты, которые сворачиваются в [_folding].
  Set<CardInstanceId> _leaving = const {};
  Timer? _foldTimer;

  Duration get _swap => Duration(
    milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : widget.style.ms(StageTokens.redrawSwap),
  );

  List<CardInstance> _sorted(PlayerView view) => _content!.handOrder(view.me.hand ?? const <CardInstance>[]);

  @override
  void didUpdateWidget(MatchRedrawView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shownBefore = _folding ?? _sorted(oldWidget.view);
    final before = {for (final card in shownBefore) card.id};
    final now = {for (final card in widget.view.me.hand ?? const <CardInstance>[]) card.id};
    final arrived = {
      for (final id in now)
        if (!before.contains(id) && !_leaving.contains(id)) id,
    };
    final removed = {
      for (final id in before)
        if (!now.contains(id)) id,
    };
    final swap = _swap;
    if (removed.isNotEmpty && swap > Duration.zero) {
      _folding = shownBefore;
      _leaving = removed;
      _foldTimer?.cancel();
      _foldTimer = Timer(swap, () {
        if (mounted) {
          setState(() {
            _folding = null;
            _leaving = const {};
          });
        }
      });
    } else {
      _foldTimer?.cancel();
      _folding = null;
      _leaving = const {};
    }
    if (arrived.isEmpty) return;
    _fresh = {..._fresh, ...arrived};
    _freshTimer?.cancel();
    _freshTimer = Timer(Duration(milliseconds: widget.style.ms(StageTokens.redrawHold)), () {
      if (mounted) setState(() => _fresh = const {});
    });
  }

  @override
  void dispose() {
    _freshTimer?.cancel();
    _foldTimer?.cancel();
    super.dispose();
  }

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
    final folding = _folding != null;
    final canReplace = left > 0 && !widget.settled && !folding;
    final swap = _swap;
    final limit = roster.content.rules.redrawLimit;
    final factionName = content.factionName(me.faction);
    final hand = _folding ?? _sorted(view);
    final rows = [
      for (var i = 0; i < hand.length; i += _columns)
        hand.sublist(i, i + _columns > hand.length ? hand.length : i + _columns),
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
                      Flexible(child: ScreenTitle(l10n.matchRedrawTitle, size: 34)),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final card in row)
                              _Appear(
                                key: ValueKey(card.id),
                                duration: swap,
                                animated: _leaving.contains(card.id) || _fresh.contains(card.id),
                                leaving: _leaving.contains(card.id),
                                child: GwentCard(
                                  key: ValueKey(card.id),
                                  face: content.face(card),
                                  size: CardSize.grid,
                                  highlight: _fresh.contains(card.id)
                                      ? CardHighlight.justPlayed
                                      : canReplace
                                      ? CardHighlight.normal
                                      : CardHighlight.disabled,
                                  onTap: canReplace ? () => widget.onIntent(RedrawCard(card.id)) : null,
                                  onLongPress: () => unawaited(showCardDetail(context, content.detail(card))),
                                ),
                              ),
                            // Неполный ряд занимает свои места колонок, иначе карты в нём сползли бы друг к другу.
                            for (var i = row.length; i < _columns; i++) SizedBox(width: _cardWidth),
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
                    onPressed: widget.settled ? null : () => widget.onIntent(const FinishRedraw()),
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

/// Появление и уход карты: пришедшая карта проявляется и вырастает, уходящая сворачивается и гаснет.
///
/// Карты, которые только сдвинулись на новое место, не анимируются: [animated] у них ложно.
class _Appear extends StatelessWidget {
  const _Appear({
    super.key,
    required this.duration,
    required this.animated,
    required this.leaving,
    required this.child,
  });

  final Duration duration;
  final bool animated;
  final bool leaving;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: !animated
          ? Tween(begin: 1, end: 1)
          : leaving
          ? Tween(begin: 1, end: 0)
          : Tween(begin: 0, end: 1),
      duration: duration,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: 0.8 + 0.2 * value, child: child),
      ),
      child: child,
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
                  ScreenTitle(l10n.matchRedrawOpponentBusy, size: 32, align: TextAlign.center),
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
