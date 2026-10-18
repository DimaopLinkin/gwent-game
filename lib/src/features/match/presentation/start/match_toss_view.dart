import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/screen_labels.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/start/start_parts.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;

/// Жребий или итог выбора Скоя'таэлей (макет 4, экран 2).
///
/// Жребий — золотая монета с гербами игроков на сторонах: 2,6 с она летит вверх, делает пять оборотов, падает и
/// подпрыгивает. После приземления чип победителя загорается золотом, внизу появляется результат. Если первого
/// выбрал игрок Скоя'таэлей, монеты нет: показывается медаль с гербом и результат. Результат держится
/// [hold], нажатие в любой момент заканчивает экран.
class MatchTossView extends StatefulWidget {
  /// Создаёт экран: [first] ходит первым, [byChoice] — его назначил игрок Скоя'таэлей, а не жребий.
  const MatchTossView({
    super.key,
    required this.roster,
    required this.first,
    required this.byChoice,
    required this.onFinished,
  });

  /// Сколько летит монета.
  static const Duration flip = Duration(milliseconds: 2600);

  /// Сколько держится результат.
  static const Duration hold = Duration(milliseconds: 2600);

  /// Участники партии.
  final MatchRoster roster;

  /// Кто ходит первым.
  final Seat first;

  /// Первого игрока выбрал игрок Скоя'таэлей.
  final bool byChoice;

  /// Экран закончился.
  final VoidCallback onFinished;

  @override
  State<MatchTossView> createState() => _MatchTossViewState();
}

class _MatchTossViewState extends State<MatchTossView> with SingleTickerProviderStateMixin {
  /// Полёт монеты; без монеты (выбор Скоя'таэлей или «уменьшить движение») его нет.
  AnimationController? _controller;
  Timer? _timer;
  bool _landed = false;
  bool _finished = false;
  bool _started = false;
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
    if (_started) return;
    _started = true;
    if (widget.byChoice || MediaQuery.disableAnimationsOf(context)) {
      _land();
    } else {
      _controller = AnimationController(vsync: this, duration: MatchTossView.flip)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _land();
        });
      unawaited(_controller!.forward());
    }
  }

  void _land() {
    if (_landed) return;
    setState(() => _landed = true);
    _timer = Timer(MatchTossView.hold, _finish);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final roster = widget.roster;
    final content = _content!;
    final me = Seat.values.firstWhere(roster.isLocal);
    final opponent = me.opponent;
    GwentFaction factionOf(Seat seat) => content.faction(roster.player(seat).faction);
    final firstIsMe = widget.first == me;
    final title = widget.byChoice ? l10n.matchTossChoiceTitle : l10n.matchTossTitle;
    final result = roster.hotSeat
        ? l10n.matchTossHotFirst(roster.name(widget.first, l10n))
        : firstIsMe
        ? l10n.matchTossYouFirst
        : l10n.matchTossOpponentFirst;
    final note = widget.byChoice
        ? l10n.matchTossNoteChoice
        : roster.bothScoiatael
        ? l10n.matchTossNoteBothScoiatael
        : l10n.matchTossNoteRandom;
    return Semantics(
      container: true,
      button: true,
      label: l10n.matchIntroSkipSemantics,
      onTap: _finish,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: StartBackdrop(
          centerGlow: const Color(0x24C8A35B),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              children: [
                const SizedBox(height: 14),
                SizedBox(
                  height: 64,
                  child: Column(
                    spacing: 6,
                    children: [
                      Text(
                        title.toUpperCase(),
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 26,
                          height: 1,
                          letterSpacing: 26 * 0.14,
                          color: GwentColors.gold,
                        ),
                      ),
                      if (!_landed && !widget.byChoice) StartBody(l10n.matchTossFlipping),
                    ],
                  ),
                ),
                SizedBox(
                  width: 260,
                  height: 400,
                  child: widget.byChoice
                      ? const Center(
                          child: FactionMedal(
                            faction: GwentFaction.scoiatael,
                            size: 168,
                            glow: true,
                          ),
                        )
                      : _Coin(
                          animation: _controller ?? kAlwaysCompleteAnimation,
                          front: factionOf(me),
                          back: factionOf(opponent),
                          endsOnFront: firstIsMe,
                          reduced: MediaQuery.disableAnimationsOf(context),
                        ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 12,
                  children: [
                    for (final seat in [me, opponent])
                      _Chip(
                        faction: factionOf(seat),
                        label: roster.name(seat, l10n),
                        state: !_landed
                            ? _ChipState.neutral
                            : seat == widget.first
                            ? _ChipState.winner
                            : _ChipState.loser,
                      ),
                  ],
                ),
                if (_landed)
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) => Opacity(
                        opacity: t,
                        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          spacing: 8,
                          children: [
                            ScreenTitle(result, size: 38, color: GwentColors.goldHighlight, align: TextAlign.center),
                            StartBody(note, size: 14.5, italic: true),
                          ],
                        ),
                      ),
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

enum _ChipState { neutral, winner, loser }

class _Chip extends StatelessWidget {
  const _Chip({required this.faction, required this.label, required this.state});

  final GwentFaction faction;
  final String label;
  final _ChipState state;

  @override
  Widget build(BuildContext context) {
    final crest = faction.crest;
    final winner = state == _ChipState.winner;
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: GwentColors.bg,
        boxShadow: winner
            ? const [
                BoxShadow(color: Color(0x59C8A35B), blurRadius: 14),
                BoxShadow(color: GwentColors.gold, spreadRadius: 1.5),
              ]
            : const [BoxShadow(color: GwentColors.line, spreadRadius: 1)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (crest != null) GwentIconView(crest, size: 26),
          Text(
            label,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              height: 1,
              letterSpacing: 17 * 0.04,
              color: switch (state) {
                _ChipState.winner => GwentColors.goldHighlight,
                _ChipState.loser => GwentColors.textSecondary,
                _ChipState.neutral => GwentColors.textPrimary,
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Летящая монета: подъём, пять оборотов, падение и отскок; тень на земле меняется вместе с высотой.
class _Coin extends StatelessWidget {
  const _Coin({
    required this.animation,
    required this.front,
    required this.back,
    required this.endsOnFront,
    required this.reduced,
  });

  static const double _size = 124;
  static const double _lift = 250;

  final Animation<double> animation;
  final GwentFaction front;
  final GwentFaction back;
  final bool endsOnFront;
  final bool reduced;

  /// Высота над землёй в 0…1 (1 — верхняя точка) и масштаб по ходу полёта: подъём 42 %, падение до 84 %, отскок.
  static (double, double) _arc(double t) {
    if (t < 0.42) {
      final k = Curves.easeOutCubic.transform(t / 0.42);
      return (k, 1 + 0.5 * k);
    }
    if (t < 0.84) {
      final k = Curves.easeInCubic.transform((t - 0.42) / 0.42);
      return (1 - k, 1.5 - 0.5 * k);
    }
    if (t < 0.92) {
      final k = (t - 0.84) / 0.08;
      return (14 / _lift * math.sin(k * math.pi), 1);
    }
    return (0, 1);
  }

  static (double, double) _shadow(double t) {
    if (t < 0.42) return (1 - 0.55 * (t / 0.42), 0.7 - 0.45 * (t / 0.42));
    if (t < 0.84) {
      final k = (t - 0.42) / 0.42;
      return (0.45 + 0.55 * k, 0.25 + 0.45 * k);
    }
    if (t < 0.92) {
      final k = math.sin((t - 0.84) / 0.08 * math.pi);
      return (1 - 0.15 * k, 0.7 - 0.2 * k);
    }
    return (1, 0.7);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = reduced ? 1.0 : animation.value;
      final (height, scale) = _arc(t);
      final (shadowScale, shadowOpacity) = _shadow(t);
      final turns = endsOnFront ? 5.0 : 5.5;
      final angle = Curves.easeOut.transform(t) * turns * 2 * math.pi;
      final showBack = math.cos(angle) < 0;
      final face = showBack ? back : front;
      return Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 34,
            child: Opacity(
              opacity: shadowOpacity,
              child: Transform.scale(
                scale: shadowScale,
                child: Container(
                  width: 110,
                  height: 20,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical(55, 10)),
                    color: Color(0xBF000000),
                    boxShadow: [BoxShadow(color: Color(0xBF000000), blurRadius: 7)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 44 + height * _lift,
            child: Transform.scale(
              scale: scale,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 1 / 900)
                  ..rotateX(angle),
                child: Transform(
                  alignment: Alignment.center,
                  // Обратная сторона монеты нарисована после переворота: её надо развернуть, чтобы герб не был зеркальным.
                  transform: Matrix4.identity()..rotateX(showBack ? math.pi : 0),
                  child: FactionMedal(faction: face, size: _size),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
