import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/start/start_parts.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;

/// Знакомство перед партией (макет 4, экран 1): соперник сверху, «ПРОТИВ» посередине, я снизу.
///
/// У каждого — мини-карта лидера, имя, фракция и колода. Экран держится 3,2 с, внизу бежит полоса времени;
/// нажатие пропускает знакомство. Оба игрока в hot-seat называются «Игрок 1» и «Игрок 2», первый внизу.
class MatchIntroView extends StatefulWidget {
  /// Создаёт экран; [onFinished] вызывается один раз: по истечении времени или по нажатию.
  const MatchIntroView({super.key, required this.roster, required this.onFinished});

  /// Сколько держится знакомство.
  static const Duration duration = Duration(milliseconds: 3200);

  /// Участники партии.
  final MatchRoster roster;

  /// Знакомство закончилось.
  final VoidCallback onFinished;

  @override
  State<MatchIntroView> createState() => _MatchIntroViewState();
}

class _MatchIntroViewState extends State<MatchIntroView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: MatchIntroView.duration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });

  bool _finished = false;
  FieldContent? _content;
  AppLocalizations? _l10n;

  @override
  void initState() {
    super.initState();
    _controller.forward();
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

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final roster = widget.roster;
    final bottom = Seat.values.firstWhere(roster.isLocal);
    final top = bottom.opponent;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final content = _content!;
    return Semantics(
      container: true,
      button: true,
      label: l10n.matchIntroSkipSemantics,
      onTap: _finish,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: StartBackdrop(
          topGlow: content.faction(roster.player(top).faction).glow,
          bottomGlow: content.faction(roster.player(bottom).faction).glow,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      return Column(
                        children: [
                          Expanded(
                            child: _slide(
                              reduce ? 1 : Curves.easeOutCubic.transform(_phase(t, 0, 0.22)),
                              from: -40,
                              child: _Side(roster: roster, seat: top, content: content, alignEnd: true),
                            ),
                          ),
                          _Versus(
                            progress: reduce ? 1 : _phase(t, 0.17, 0.39),
                            label: l10n.matchIntroVersus,
                          ),
                          Expanded(
                            child: _slide(
                              reduce ? 1 : Curves.easeOutCubic.transform(_phase(t, 0.06, 0.28)),
                              from: 40,
                              child: _Side(roster: roster, seat: bottom, content: content, alignEnd: false),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: 140,
                right: 140,
                bottom: 22,
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: GwentColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _controller.value,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(2)),
                              gradient: LinearGradient(colors: [GwentColors.brassLight, GwentColors.goldHighlight]),
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
      ),
    );
  }

  /// Доля [t] между [begin] и [end], от 0 до 1.
  static double _phase(double t, double begin, double end) => ((t - begin) / (end - begin)).clamp(0.0, 1.0);

  static Widget _slide(double progress, {required double from, required Widget child}) => Opacity(
    opacity: progress,
    child: Transform.translate(offset: Offset(0, from * (1 - progress)), child: child),
  );
}

/// Игрок: мини-карта лидера и колонка с именем, фракцией и колодой. Соперник сверху прижат к правому краю.
class _Side extends StatelessWidget {
  const _Side({required this.roster, required this.seat, required this.content, required this.alignEnd});

  final MatchRoster roster;
  final Seat seat;
  final FieldContent content;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final player = roster.player(seat);
    final faction = content.faction(player.faction);
    final crossAxis = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final align = alignEnd ? TextAlign.end : TextAlign.start;
    final card = SizedBox(
      width: CardSize.hand.metrics.width,
      height: CardSize.hand.metrics.height,
      child: GwentCard(face: content.leaderFace(player.leader), size: CardSize.hand),
    );
    final info = Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: crossAxis,
        spacing: 7,
        children: [
          Eyebrow(content.leaderFace(player.leader).name, align: align),
          StartTitle(roster.name(seat, l10n), size: 36, align: align),
          FactionLine(
            faction: faction,
            name: content.factionName(player.faction),
            crestFirst: !alignEnd,
          ),
          if (player.deckName case final deck?)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${l10n.matchIntroDeck} '),
                  TextSpan(
                    text: '«$deck»',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      color: GwentColors.goldHighlight,
                    ),
                  ),
                ],
              ),
              textAlign: align,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.alegreya,
                fontWeight: FontWeight.w500,
                fontSize: 14,
                height: 1.3,
                color: GwentColors.textSecondary,
              ),
            ),
        ],
      ),
    );
    return Row(spacing: 18, children: alignEnd ? [card, info] : [info, card]);
  }
}

/// Разделитель «ПРОТИВ»: линии латуни и золотые ромбы по краям слова.
class _Versus extends StatelessWidget {
  const _Versus({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scale = progress < 0.7 ? 0.6 + 0.48 * (progress / 0.7) : 1.08 - 0.08 * ((progress - 0.7) / 0.3);
    return SizedBox(
      height: 92,
      child: Opacity(
        opacity: progress.clamp(0, 1),
        child: Transform.scale(
          scale: scale,
          child: Row(
            spacing: 14,
            children: [
              const Expanded(child: _Rule(towardsEnd: false)),
              const _GoldDiamond(),
              Text(
                label,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w700,
                  fontSize: 44,
                  height: 1,
                  letterSpacing: 44 * 0.2,
                  color: GwentColors.gold,
                ),
              ),
              const _GoldDiamond(),
              const Expanded(child: _Rule(towardsEnd: true)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.towardsEnd});

  final bool towardsEnd;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: towardsEnd
              ? const [GwentColors.brass, Color(0x008C6A3F)]
              : const [Color(0x008C6A3F), GwentColors.brass],
        ),
      ),
    ),
  );
}

class _GoldDiamond extends StatelessWidget {
  const _GoldDiamond();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.7853981633974483,
    child: const SizedBox.square(
      dimension: 7,
      child: ColoredBox(color: GwentColors.gold),
    ),
  );
}
