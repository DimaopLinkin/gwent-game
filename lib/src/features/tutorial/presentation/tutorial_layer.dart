import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/confirm_dialog.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/player_bar.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/field_lesson.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/tutorial/domain/hint_target.dart';
import 'package:gwent/src/features/tutorial/domain/scenario_beat.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_move.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_step.dart';
import 'package:gwent/src/features/tutorial/presentation/hint_scrim.dart';
import 'package:gwent/src/features/tutorial/presentation/tutorial_cubit.dart';
import 'package:gwent/src/features/tutorial/presentation/tutorial_state.dart';
import 'package:gwent/src/features/tutorial/presentation/tutorial_texts.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Row;

/// Слой подсказок «Первой партии» поверх поля (макет 16, ADR 0034).
///
/// Затемняет поле и оставляет окна на том, что объясняет текущий шаг; нажатия в окнах идут к полю, остальные ловит
/// затемнение и сообщает о них режиссёру сценария. Карточка с текстом стоит в свободной части экрана, не закрывая
/// окон. Пока поле что-то показывает (баннеры, анимации карт, итог раунда, пауза, листы) или идёт ход бота, слой
/// молчит: подсказка появляется, когда игрок может действовать.
class TutorialLayer extends StatefulWidget {
  /// Создаёт слой для поля [layout]; [onSkip] уводит из обучения после подтверждения «Пропустить».
  const TutorialLayer({super.key, required this.layout, required this.onSkip});

  /// Что слой знает о поле.
  final FieldLayout layout;

  /// Игрок подтвердил, что хочет пропустить обучение.
  final VoidCallback onSkip;

  @override
  State<TutorialLayer> createState() => _TutorialLayerState();
}

class _TutorialLayerState extends State<TutorialLayer> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  Map<GlobalKey, Rect> _measured = const {};

  /// Пока слой что-то рисует, места на поле перемеряются каждый кадр: карты в руке поворачиваются и поднимаются.
  late final Ticker _ticker = createTicker((_) => _measure());

  /// Пульс рамок и перемеры идут, только пока слой на виду: на ходах бота и анимациях он молчит и кадров не просит.
  void _setActive({required bool active}) {
    final pulsing = active && !MediaQuery.disableAnimationsOf(context);
    if (active && !_ticker.isActive) unawaited(_ticker.start());
    if (!active && _ticker.isActive) _ticker.stop();
    if (pulsing && !_pulse.isAnimating) unawaited(_pulse.repeat(reverse: true));
    if (!pulsing && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Iterable<GlobalKey> get _anchorKeys sync* {
    final mine = widget.layout.anchors[true]!;
    final theirs = widget.layout.anchors[false]!;
    yield* [mine.leader, mine.deck, mine.discard, mine.score, mine.gems, mine.trailing, theirs.score, theirs.gems];
    yield* widget.layout.handKeys.values;
  }

  /// Метки частей полос и карт лежат внутри поля, масштабированного по холсту, поэтому их место читается из
  /// отрисованных объектов после раскладки, а не считается по геометрии.
  void _measure() {
    final me = context.findRenderObject();
    if (me is! RenderBox || !me.hasSize) return;
    final next = <GlobalKey, Rect>{};
    for (final key in _anchorKeys) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final global = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
      next[key] = Rect.fromPoints(me.globalToLocal(global.topLeft), me.globalToLocal(global.bottomRight));
    }
    if (!_sameRects(next, _measured)) setState(() => _measured = next);
  }

  static bool _sameRects(Map<GlobalKey, Rect> a, Map<GlobalKey, Rect> b) =>
      a.length == b.length && a.entries.every((entry) => b[entry.key] == entry.value);

  Rect _scaled(Rect rect) {
    final scale = widget.layout.fit.scale;
    return Rect.fromLTRB(rect.left * scale, rect.top * scale, rect.right * scale, rect.bottom * scale);
  }

  /// Окна, которые подсвечивают [target]: цель может занимать несколько мест (камни обоих игроков).
  List<HintWindow> _windows(HintTarget target, {required bool interactive}) {
    final layout = widget.layout;
    final geometry = layout.geometry;
    HintWindow window(Rect frame, {Rect? touch}) => HintWindow(frame, touch: interactive ? touch ?? frame : null);
    HintWindow? anchored(GlobalKey key) => switch (_measured[key]) {
      final Rect rect => window(rect.inflate(2)),
      null => null,
    };
    final mine = layout.anchors[true]!;
    final theirs = layout.anchors[false]!;
    return switch (target) {
      GemsHint() => [?anchored(mine.gems), ?anchored(theirs.gems)],
      HandHint() => [window(_scaled(geometry.hand))],
      PilesHint() => [
        if (_measured[mine.deck] case final deck?)
          if (_measured[mine.discard] case final discard?) window(deck.expandToInclude(discard).inflate(2)),
      ],
      HandCardHint(:final cardId) => _handCardWindows(cardId, interactive: interactive),
      RowHint(:final row, :final mine) => [window(_scaled(geometry.rowRect(row, mine: mine)))],
      RowScoreHint(:final row, :final mine) => [window(_scaled(geometry.scoreRect(row, mine: mine)).inflate(2))],
      StripHint() => [window(_scaled(geometry.strip))],
      ScoreHint(:final mine) => [?anchored(mine ? _mineAnchors.score : theirs.score)],
      PassHint() => [?anchored(mine.trailing)],
      LeaderHint() => [?anchored(mine.leader)],
    };
  }

  PlayerBarAnchors get _mineAnchors => widget.layout.anchors[true]!;

  List<HintWindow> _handCardWindows(String cardId, {required bool interactive}) {
    final layout = widget.layout;
    final hand = layout.hand;
    final index = hand.indexWhere((card) => card.cardId.value == cardId);
    if (index < 0) return const [];
    final card = hand[index];
    // Карта измеряется там, где она нарисована: веер поворачивает карты, выбранная карта поднимается, а в режиме
    // прокрутки место зависит от сдвига.
    final frame = switch (layout.handKeys[card.id]) {
      final GlobalKey key when _measured.containsKey(key) => _measured[key]!,
      _ => null,
    };
    if (frame == null) return const [];
    // В веере карты лежат внахлёст: нажатие по закрытой соседом части попало бы в соседа, поэтому пропускаем только
    // видимую полосу карты. Последняя и выбранная карта лежат сверху целиком.
    final geometry = layout.geometry;
    final scale = layout.fit.scale;
    var touch = frame;
    final covered = index < hand.length - 1 && card.id != layout.field.selected && !geometry.handScrolls(hand.length);
    if (covered) {
      final stripe = geometry.fanStep(hand.length) * scale;
      touch = Rect.fromLTWH(frame.center.dx - (77 * scale - stripe) / 2 - stripe / 2, frame.top, stripe, frame.height);
    }
    return [HintWindow(frame, touch: interactive ? touch : null)];
  }

  Future<void> _skip() async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.tutorialSkipTitle,
      body: l10n.tutorialSkipBody,
      confirmLabel: l10n.tutorialSkipConfirm,
    );
    if (confirmed && mounted) widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    return BlocBuilder<TutorialCubit, TutorialState>(
      builder: (context, state) {
        final beat = state.beat;
        final field = layout.field;
        final quiet =
            beat == null ||
            beat is BotBeat ||
            field.isBusy ||
            field.overlay is! NoOverlay ||
            layout.view.choice != null ||
            layout.view.phase != MatchPhase.playing;
        _setActive(active: !quiet);
        if (quiet) return const SizedBox.shrink();
        return _content(context, state, beat);
      },
    );
  }

  Widget _content(BuildContext context, TutorialState state, Beat beat) {
    final l10n = context.l10n;
    final layout = widget.layout;
    final cubit = context.read<TutorialCubit>();
    final selected = layout.field.selected != null;
    final interactive = beat is PlayerBeat;

    final windows = <HintWindow>[];
    final emphasis = <int>{};
    final targets = switch (beat) {
      ShowBeat(:final targets) => targets,
      PlayerBeat(:final move, :final targets) => [
        if (move is PlayMove) ...[HandCardHint(move.cardId), ?move.destination],
        ...targets,
      ],
      BotBeat() => const <HintTarget>[],
    };
    for (final target in targets) {
      final found = _windows(target, interactive: interactive);
      // Карту подсвечивает яркая рамка, пока она не выбрана, а место для неё — после выбора.
      if (beat is PlayerBeat && beat.move is PlayMove) {
        if ((target is HandCardHint) != selected) {
          emphasis.addAll([for (var i = 0; i < found.length; i++) windows.length + i]);
        }
      }
      windows.addAll(found);
    }

    final step = switch (beat) {
      ShowBeat(:final step) => step,
      PlayerBeat(:final step) => step,
      BotBeat() => null,
    };
    final dimmed = step != null;
    final pauseRect = _scaled(layout.geometry.pauseButtonRect);
    final all = [
      ...windows,
      // Кнопка паузы работает при любом шаге: из меню паузы можно начать заново или выйти.
      if (dimmed) HintWindow(pauseRect, touch: pauseRect, framed: false),
    ];

    final now = switch (beat) {
      ShowBeat() => l10n.tutorialNowNext,
      PlayerBeat(:final move) => switch (move) {
        PlayMove() => selected ? l10n.tutorialNowTarget : l10n.tutorialNowCard,
        PassMove() => l10n.tutorialNowPass,
        LeaderMove() => l10n.tutorialNowLeader,
      },
      BotBeat() => '',
    };

    final Widget? top;
    if (step == null) {
      top = _NowPill(text: now);
    } else if (state.collapsed) {
      top = _ExpandChip(label: l10n.tutorialExpand, onPressed: cubit.toggleCollapsed);
    } else {
      final text = tutorialText(
        l10n,
        step,
        mine: layout.view.me.score,
        theirs: layout.view.opponent.score,
      );
      top = _HintCard(
        counter: l10n.tutorialStepCounter(step.number, TutorialStep.total),
        title: text.title,
        text: text.text,
        nowLine: state.nudged ? now : null,
        action: beat is ShowBeat
            ? SizedBox(
                width: 132,
                child: GwentButton(label: l10n.tutorialNext, height: 44, fontSize: 18, onPressed: cubit.acknowledge),
              )
            : Text(
                l10n.tutorialWaiting,
                textAlign: TextAlign.end,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  height: 1.2,
                  color: GwentColors.textSecondary,
                ),
              ),
        collapseLabel: l10n.tutorialCollapse,
        skipLabel: l10n.tutorialSkip,
        onCollapse: cubit.toggleCollapsed,
        onSkip: _skip,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        HintScrim(
          windows: all,
          dimmed: dimmed,
          pulse: MediaQuery.disableAnimationsOf(context) ? null : _pulse,
          emphasis: emphasis,
          onBlocked: cubit.nudge,
        ),
        CustomSingleChildLayout(
          delegate: _CardLayout(
            obstacles: [for (final window in windows) window.frame.inflate(8)],
            alignEnd: step != null && state.collapsed,
          ),
          child: top,
        ),
      ],
    );
  }
}

/// Ставит карточку подсказки в свободное место экрана: сверху, если окна её не закрывают, иначе снизу или между ними.
class _CardLayout extends SingleChildLayoutDelegate {
  const _CardLayout({required this.obstacles, required this.alignEnd});

  static const double margin = 8;
  static const double maxWidth = 420;

  final List<Rect> obstacles;
  final bool alignEnd;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
    maxWidth: math.min(constraints.maxWidth - 2 * GwentSpace.space4, maxWidth),
    maxHeight: math.max(0, constraints.maxHeight - 2 * margin),
  );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = alignEnd ? size.width - childSize.width - GwentSpace.space4 : (size.width - childSize.width) / 2;
    return Offset(left, _top(size, childSize.height));
  }

  double _top(Size size, double height) {
    // Свободные промежутки между окнами по вертикали, сверху вниз.
    final blocked = [for (final rect in obstacles) (rect.top, rect.bottom)]..sort((a, b) => a.$1.compareTo(b.$1));
    final gaps = <(double, double)>[];
    var from = margin;
    for (final (top, bottom) in blocked) {
      if (top > from) gaps.add((from, top));
      from = math.max(from, bottom);
    }
    if (size.height - margin > from) gaps.add((from, size.height - margin));
    for (final (start, end) in gaps) {
      if (end - start < height) continue;
      if (start == margin) return start;
      if (end == size.height - margin) return end - height;
      return start + (end - start - height) / 2;
    }
    // Свободного места нет: карточка прижимается к низу и закрывает часть затемнённого поля.
    return math.max(margin, size.height - margin - height);
  }

  @override
  bool shouldRelayout(_CardLayout oldDelegate) =>
      oldDelegate.alignEnd != alignEnd || !_sameRects(oldDelegate.obstacles, obstacles);

  static bool _sameRects(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Карточка подсказки: счётчик шагов, заголовок, текст и нижняя строка с «Пропустить» и действием.
class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.counter,
    required this.title,
    required this.text,
    required this.action,
    required this.collapseLabel,
    required this.skipLabel,
    required this.onCollapse,
    required this.onSkip,
    this.nowLine,
  });

  final String counter;
  final String title;
  final String text;
  final String? nowLine;
  final Widget action;
  final String collapseLabel;
  final String skipLabel;
  final VoidCallback onCollapse;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [GwentColors.surfaceRaised, Color(0xFF241D16)],
      ),
      borderRadius: BorderRadius.circular(GwentSpace.radiusL),
      border: Border.all(color: GwentColors.brass, width: GwentSpace.borderGold),
      boxShadow: GwentShadows.high,
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  counter,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1,
                    letterSpacing: 13 * 0.08,
                    color: GwentColors.textSecondary,
                  ),
                ),
              ),
              _IconTap(label: collapseLabel, onPressed: onCollapse, glyph: '−'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(
                  title,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    height: 1.1,
                    color: GwentColors.goldHighlight,
                  ),
                ),
                Text(
                  text,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    height: 1.3,
                    color: GwentColors.textPrimary,
                  ),
                ),
                if (nowLine case final line?)
                  Text(
                    line,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      height: 1.25,
                      color: GwentColors.amber,
                    ),
                  ),
                Row(
                  spacing: 12,
                  children: [
                    Semantics(
                      button: true,
                      label: skipLabel,
                      excludeSemantics: true,
                      onTap: onSkip,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onSkip,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: GwentSpace.minTapTarget),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: 1,
                            child: Text(
                              skipLabel,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontFamily: GwentText.alegreya,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                                color: GwentColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(alignment: Alignment.centerRight, child: action),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Круглая кнопка «−» и «?» с зоной нажатия 44 pt.
class _IconTap extends StatelessWidget {
  const _IconTap({required this.label, required this.onPressed, required this.glyph});

  final String label;
  final VoidCallback onPressed;
  final String glyph;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onPressed,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: GwentSpace.minTapTarget,
        child: Center(
          child: Text(
            glyph,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 26,
              height: 1,
              color: GwentColors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Свёрнутая карточка: золотой значок «?».
class _ExpandChip extends StatelessWidget {
  const _ExpandChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: GwentColors.surfaceRaised,
      border: Border.all(color: GwentColors.gold, width: GwentSpace.borderGold),
      boxShadow: GwentShadows.mid,
    ),
    child: _IconTap(label: label, onPressed: onPressed, glyph: '?'),
  );
}

/// Строка «Сейчас: …» над полем при свободном ходе, когда карточки подсказки нет.
class _NowPill extends StatelessWidget {
  const _NowPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: GwentColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(GwentSpace.radiusPill),
        border: Border.all(color: GwentColors.brass),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: GwentText.alegreya,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            fontSize: 15,
            height: 1.2,
            color: GwentColors.amber,
          ),
        ),
      ),
    ),
  );
}
