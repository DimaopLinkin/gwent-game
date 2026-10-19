import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_labels.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/start/start_parts.dart';
import 'package:gwent_engine/gwent_engine.dart' show PlayerView, Seat;

/// Итог матча (макеты 5 и 13): лист снизу поверх поля — «Победа», «Поражение» или «Ничья», счёт раундов, таблица
/// раундов, лидеры и фракции обоих игроков, кнопки «Реванш» и «В меню».
///
/// Лист выезжает из-под экрана на [sheetSlide] поверх затемнённого на 62 % поля [field] (если его нет, фон
/// рисует `StartBackdrop`). Кнопка «Показать поле» или жест вниз по шапке опускает лист до полосы 64 pt и снимает
/// затемнение, «К итогам» или жест вверх поднимает его назад. Поле только смотрят, касания до него не доходят.
///
/// «Реванш» доступен только для местной партии ([onRematch] `null` — кнопки нет). В hot-seat колонки названы по
/// игрокам, а над таблицей сказано, кто победил.
class MatchResultView extends StatefulWidget {
  /// Создаёт экран по итоговой проекции [view]; [field] — поле партии, которое видно за листом.
  const MatchResultView({
    super.key,
    required this.view,
    required this.roster,
    required this.onExit,
    this.onRematch,
    this.field,
  });

  /// Сколько лист выезжает, сворачивается и разворачивается (токен `sheet.slide` макета 13).
  static const Duration sheetSlide = Duration(milliseconds: 350);

  /// Сколько затемняется поле (токен `sheet.dim`).
  static const Duration fieldDim = Duration(milliseconds: 300);

  /// Высота листа макета.
  static const double sheetHeight = 540;

  /// Высота шапки; свёрнутый лист показывает только её.
  static const double headerHeight = 64;

  /// Итоговая проекция.
  final PlayerView view;

  /// Участники партии.
  final MatchRoster roster;

  /// Выход в меню.
  final VoidCallback onExit;

  /// Реванш; `null` — сыграть заново нельзя.
  final VoidCallback? onRematch;

  /// Поле партии за листом; `null` — спокойный фон.
  final Widget? field;

  @override
  State<MatchResultView> createState() => _MatchResultViewState();
}

class _MatchResultViewState extends State<MatchResultView> {
  /// Лист выехал: до первого кадра он стоит под экраном, чтобы выезд было видно.
  bool _entered = false;

  /// Лист свёрнут до полосы, поле открыто.
  bool _collapsed = false;

  /// Сколько прошёл палец по шапке с начала жеста, pt.
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  void _setCollapsed({required bool value}) {
    if (_collapsed != value) setState(() => _collapsed = value);
  }

  void _endDrag() {
    if (_drag > 40) {
      _setCollapsed(value: true);
    } else if (_drag < -40) {
      _setCollapsed(value: false);
    }
    _drag = 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = widget.view;
    final roster = widget.roster;
    final me = view.viewer;
    final winner = view.outcome?.winner;
    final hotSeat = roster.hotSeat;
    final draw = winner == null;
    final won = winner == me;
    final (title, titleColor, backdrop) = draw
        ? (l10n.matchFinishedDraw, GwentColors.textPrimary, const Color(0x29A09682))
        : (won || hotSeat)
        ? (l10n.matchFinishedWin, GwentColors.goldHighlight, const Color(0x4DC8963C))
        : (l10n.matchFinishedLose, GwentColors.defeat, const Color(0x57702822));
    final wins = {
      for (final seat in Seat.values) seat: view.history.where((result) => result.winner == seat).length,
    };
    final rounds = roster.content.rules.crystals + 1;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final slide = reduce ? Duration.zero : MatchResultView.sheetSlide;
    final dim = reduce ? Duration.zero : MatchResultView.fieldDim;
    final padding = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final sheetHeight = math.min(MatchResultView.sheetHeight + padding.bottom, constraints.maxHeight - padding.top);
        final strip = MatchResultView.headerHeight + padding.bottom;
        final bottom = !_entered ? -sheetHeight : (_collapsed ? strip - sheetHeight : 0.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              excluding: !_collapsed,
              child: IgnorePointer(
                child:
                    widget.field ??
                    StartBackdrop(
                      base: won || draw || hotSeat ? const Color(0xFF0F0C09) : const Color(0xFF0E0B09),
                      topGlow: backdrop,
                      child: const SizedBox.expand(),
                    ),
              ),
            ),
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _entered && !_collapsed ? 0.62 : 0,
                duration: dim,
                child: const ColoredBox(color: Color(0xFF0A0806)),
              ),
            ),
            AnimatedPositioned(
              left: 0,
              right: 0,
              height: sheetHeight,
              bottom: bottom,
              duration: slide,
              curve: _sheetCurve,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E1812), Color(0xFF14110E)],
                  ),
                  boxShadow: [
                    BoxShadow(color: GwentColors.brass, offset: Offset(0, -1)),
                    BoxShadow(color: Color(0x99000000), blurRadius: 40, offset: Offset(0, -12)),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 22 + padding.bottom),
                  child: Column(
                    children: [
                      _SheetHeader(
                        title: title,
                        titleColor: titleColor,
                        score: '${wins[me] ?? 0} : ${wins[me.opponent] ?? 0}',
                        collapsed: _collapsed,
                        onToggle: () => _setCollapsed(value: !_collapsed),
                        onDragStart: () => _drag = 0,
                        onDragDelta: (delta) => _drag += delta,
                        onDragEnd: _endDrag,
                      ),
                      Expanded(
                        child: ExcludeSemantics(
                          excluding: _collapsed,
                          child: _SheetBody(view: view, roster: roster, rounds: rounds),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ExcludeSemantics(
                        excluding: _collapsed,
                        child: Row(
                          spacing: 12,
                          children: [
                            if (widget.onRematch != null)
                              Expanded(
                                flex: 12,
                                child: GwentButton(
                                  label: l10n.matchResultRematch,
                                  height: 56,
                                  fontSize: 24,
                                  onPressed: widget.onRematch,
                                ),
                              ),
                            Expanded(
                              flex: 10,
                              child: GwentButton(
                                label: l10n.matchExit,
                                style: GwentButtonStyle.secondary,
                                height: 56,
                                onPressed: widget.onExit,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Кривая выезда макета, `cubic-bezier(.22, 1, .36, 1)`.
  static const Curve _sheetCurve = Cubic(0.22, 1, 0.36, 1);
}

/// Шапка листа: ручка, «Победа · 2 : 1» и кнопка «Показать поле»/«К итогам». Жест по шапке сворачивает и
/// разворачивает лист.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.titleColor,
    required this.score,
    required this.collapsed,
    required this.onToggle,
    required this.onDragStart,
    required this.onDragDelta,
    required this.onDragEnd,
  });

  final String title;
  final Color titleColor;
  final String score;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragDelta;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => onDragStart(),
      onVerticalDragUpdate: (details) => onDragDelta(details.delta.dy),
      onVerticalDragEnd: (_) => onDragEnd(),
      child: SizedBox(
        height: MatchResultView.headerHeight,
        child: Row(
          spacing: 10,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: GwentColors.line,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                    child: SizedBox(width: 36, height: 4),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      spacing: 8,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: GwentText.cormorant,
                            fontWeight: FontWeight.w700,
                            fontSize: 26,
                            height: 1,
                            letterSpacing: 26 * 0.03,
                            color: titleColor,
                          ),
                        ),
                        Text(
                          '· $score',
                          maxLines: 1,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: GwentText.cormorant,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            height: 1,
                            color: GwentColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: collapsed ? l10n.matchResultShowResults : l10n.matchResultShowField,
              excludeSemantics: true,
              onTap: onToggle,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: SizedBox(
                  height: GwentSpace.minTapTarget,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: GwentColors.brass),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          collapsed ? l10n.matchResultShowResults : l10n.matchResultShowField,
                          maxLines: 1,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: GwentText.cormorant,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            height: 1,
                            letterSpacing: 17 * 0.05,
                            color: GwentColors.textPrimary,
                          ),
                        ),
                      ),
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

/// Прокручиваемая середина листа: победитель в hot-seat, таблица раундов и оба игрока.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.view, required this.roster, required this.rounds});

  final PlayerView view;
  final MatchRoster roster;
  final int rounds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = FieldContent(content: roster.content, l10n: l10n);
    final me = view.viewer;
    final winner = view.outcome?.winner;
    return SingleChildScrollView(
      child: Column(
        children: [
          if (roster.hotSeat && winner != null) ...[
            StartBody(
              l10n.matchResultWinnerHot(roster.name(winner, l10n)),
              size: 17,
              color: GwentColors.textTertiary,
            ),
            const SizedBox(height: 10),
          ],
          _Table(view: view, roster: roster, rounds: rounds),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              for (final seat in [me, me.opponent])
                Expanded(
                  child: _Player(seat: seat, roster: roster, content: content),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.view, required this.roster, required this.rounds});

  final PlayerView view;
  final MatchRoster roster;
  final int rounds;

  static const TextStyle _head = TextStyle(
    fontFamily: GwentText.cormorant,
    fontWeight: FontWeight.w700,
    fontSize: 11.5,
    height: 1,
    letterSpacing: 11.5 * 0.06,
    color: GwentColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final me = view.viewer;
    String nameOf(Seat seat) => roster.name(seat, l10n);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0x8C0A0806),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: GwentColors.line, spreadRadius: 1)],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 30,
            child: _row(
              Text(l10n.matchResultColumnRound.toUpperCase(), style: _head, textScaler: TextScaler.noScaling),
              Text(
                nameOf(me).toUpperCase(),
                style: _head,
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
              Text(
                nameOf(me.opponent).toUpperCase(),
                style: _head,
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
              Text(
                l10n.matchResultColumnWinner.toUpperCase(),
                style: _head,
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.end,
                maxLines: 1,
              ),
            ),
          ),
          for (var i = 0; i < rounds; i++) _roundRow(l10n, i, me),
        ],
      ),
    );
  }

  Widget _roundRow(AppLocalizations l10n, int index, Seat me) {
    final result = view.history.where((result) => result.round == index + 1).firstOrNull;
    final mine = result?.scores[me];
    final theirs = result?.scores[me.opponent];
    final winner = result?.winner;
    const win = GwentColors.goldHighlight;
    const muted = GwentColors.muted;
    Color scoreColor(Seat seat) => result == null
        ? muted
        : winner == null
        ? GwentColors.textPrimary
        : winner == seat
        ? win
        : GwentColors.loserText;
    Widget score(int? value, Seat seat) => Text(
      value == null ? '—' : '$value',
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: GwentText.alegreya,
        fontWeight: FontWeight.w800,
        fontSize: 22,
        height: 1,
        fontFeatures: GwentText.numbers,
        color: scoreColor(seat),
      ),
    );
    final winnerText = result == null
        ? '—'
        : winner == null
        ? l10n.matchFinishedDraw
        : roster.name(winner, l10n);
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: GwentColors.surfaceRaised)),
        ),
        child: _row(
          Text(
            l10n.matchResultRound(index + 1),
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: GwentText.alegreya,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              height: 1,
              color: GwentColors.textTertiary,
            ),
          ),
          score(mine, me),
          score(theirs, me.opponent),
          Text(
            winnerText,
            maxLines: 1,
            textAlign: TextAlign.end,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1,
              letterSpacing: 15 * 0.05,
              color: result == null
                  ? muted
                  : winner == me
                  ? win
                  : winner == null
                  ? GwentColors.textSecondary
                  : GwentColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(Widget round, Widget mine, Widget theirs, Widget winner) => Row(
    spacing: 8,
    children: [
      SizedBox(width: 60, child: round),
      SizedBox(width: 50, child: Center(child: mine)),
      SizedBox(width: 88, child: Center(child: theirs)),
      Expanded(
        child: Align(alignment: Alignment.centerRight, child: winner),
      ),
    ],
  );
}

class _Player extends StatelessWidget {
  const _Player({required this.seat, required this.roster, required this.content});

  final Seat seat;
  final MatchRoster roster;
  final FieldContent content;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final player = roster.player(seat);
    final faction = content.faction(player.faction);
    final leader = content.leaderFace(player.leader);
    return Column(
      spacing: 10,
      children: [
        SizedBox(
          width: CardSize.hand.metrics.width,
          height: CardSize.hand.metrics.height,
          child: GwentCard(face: leader, size: CardSize.hand),
        ),
        Eyebrow(roster.name(seat, l10n), size: 12, align: TextAlign.center),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 6,
          children: [
            if (faction.crest case final crest?) GwentIconView(crest, size: 24),
            Flexible(
              child: Text(
                content.factionName(player.faction),
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  height: 1.1,
                  color: GwentColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        StartBody(leader.name, size: 14),
      ],
    );
  }
}
