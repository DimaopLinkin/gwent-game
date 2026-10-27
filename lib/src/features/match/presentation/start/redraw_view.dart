import 'dart:async';
import 'dart:math' as math;

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
/// Замена видна: старая карта уходит, рука встаёт в новом порядке, а новая карта влетает из колоды (снизу справа), как
/// при доборе в партии: по дуге, переворачиваясь рубашкой вверх и лицом вниз, и ложится на своё отсортированное место
/// и светится, пока её не заметили. После последней замены экран (`MatchRedrawSettled`) на время остаётся с [settled]:
/// карты и «Готово» недоступны, пришедшая карта на виду, и только потом игрок уходит на ожидание соперника.
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

  /// Карты, которые ещё летят из колоды: их место в сетке пусто, а карту рисует слой полёта.
  Set<CardInstanceId> _arriving = const {};

  /// Область с картами: полёт рисуется в ней поверх сетки, от её нижнего края.
  final GlobalKey _areaKey = GlobalKey();

  /// Места карт в сетке: по ним слой полёта находит, куда садиться, даже если карта сменила ряд.
  final Map<CardInstanceId, GlobalKey> _slots = {};

  GlobalKey _slot(CardInstanceId id) => _slots.putIfAbsent(id, GlobalKey.new);

  Duration get _flight => Duration(
    milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : widget.style.ms(StageTokens.flight),
  );

  List<CardInstance> _sorted(PlayerView view) => _content!.handOrder(view.me.hand ?? const <CardInstance>[]);

  @override
  void didUpdateWidget(MatchRedrawView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldHand = {for (final card in oldWidget.view.me.hand ?? const <CardInstance>[]) card.id};
    final newHand = {for (final card in widget.view.me.hand ?? const <CardInstance>[]) card.id};
    final arrived = {
      for (final id in newHand)
        if (!oldHand.contains(id)) id,
    };
    // Рука та же (экран пересобрали по другой причине): ничего не перезапускается.
    if (arrived.isEmpty) return;
    _fresh = {..._fresh, ...arrived};
    _freshTimer?.cancel();
    final hold = Duration(milliseconds: widget.style.ms(StageTokens.redrawHold));
    final flight = _flight;
    // Свечение отсчитывается от посадки карты.
    _freshTimer = Timer(hold + flight, () {
      if (mounted) setState(() => _fresh = const {});
    });
    _slots.removeWhere((id, _) => !newHand.contains(id));
    _arriving = {
      for (final id in _arriving)
        if (newHand.contains(id)) id,
    };
    if (flight == Duration.zero) return;
    _arriving = {..._arriving, ...arrived};
    // Новая карта может сесть в ряд за краем экрана: прокручиваем к ней, пока она летит.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = arrived.map((id) => _slots[id]?.currentContext).nonNulls.firstOrNull;
      if (!mounted || target == null || !target.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          duration: flight,
          curve: StageTokens.out,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    });
  }

  void _landed(CardInstanceId id) {
    if (mounted && _arriving.contains(id)) setState(() => _arriving = {..._arriving}..remove(id));
  }

  @override
  void dispose() {
    _freshTimer?.cancel();
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
    final canReplace = left > 0 && !widget.settled;
    final limit = roster.content.rules.redrawLimit;
    final factionName = content.factionName(me.faction);
    final hand = _sorted(view);
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
              key: _areaKey,
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
                              Opacity(
                                key: _slot(card.id),
                                opacity: _arriving.contains(card.id) ? 0 : 1,
                                child: GwentCard(
                                  key: ValueKey(card.id),
                                  face: content.face(card),
                                  size: CardSize.grid,
                                  highlight: _fresh.contains(card.id)
                                      ? CardHighlight.justPlayed
                                      : canReplace
                                      ? CardHighlight.normal
                                      : CardHighlight.disabled,
                                  onTap: canReplace && !_arriving.contains(card.id)
                                      ? () => widget.onIntent(RedrawCard(card.id))
                                      : null,
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
                for (final card in hand)
                  if (_arriving.contains(card.id))
                    _Flight(
                      key: ValueKey(card.id),
                      slot: _slot(card.id),
                      area: _areaKey,
                      duration: _flight,
                      back: GwentCard(
                        face: CardBackFace(faction: content.faction(me.faction)),
                        size: CardSize.grid,
                      ),
                      front: GwentCard(face: content.face(card), size: CardSize.grid),
                      onLanded: () => _landed(card.id),
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

/// Влёт пришедшей карты: как добор в партии (`StageBuilder`), карта вылетает из колоды по дуге, переворачивается
/// рубашкой в лицо и растёт от половины размера до полного.
///
/// Карту рисует слой поверх сетки (в сетке на это время пустое место [slot]), поэтому другие карты её не закрывают.
/// Колода стоит у нижнего края области [area] справа.
class _Flight extends StatefulWidget {
  const _Flight({
    super.key,
    required this.slot,
    required this.area,
    required this.duration,
    required this.back,
    required this.front,
    required this.onLanded,
  });

  /// Место карты в сетке: куда она садится.
  final GlobalKey slot;

  /// Область, в которой рисуется полёт.
  final GlobalKey area;

  final Duration duration;

  /// Рубашка, видимая в первой половине переворота.
  final Widget back;

  /// Лицо карты.
  final Widget front;

  /// Полёт кончился.
  final VoidCallback onLanded;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  static const double _arc = -24;
  static const double _startScale = 0.5;

  late final AnimationController _controller;

  /// Сетка разложена, можно считать путь: до этого карта невидима, чтобы не мелькнуть не там.
  bool _placed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onLanded();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _placed = true);
      unawaited(_controller.forward());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Центры колоды и места карты в координатах области; `null`, пока что-то не разложено.
  ({Offset deck, Offset target})? _path() {
    final area = widget.area.currentContext?.findRenderObject();
    final slot = widget.slot.currentContext?.findRenderObject();
    if (area is! RenderBox || slot is! RenderBox || !area.hasSize || !slot.hasSize || !slot.attached) return null;
    final card = CardSize.grid.metrics;
    return (
      deck: Offset(area.size.width - 16 - card.width / 2, area.size.height - card.height / 2),
      target: area.globalToLocal(slot.localToGlobal(slot.size.center(Offset.zero))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final path = _placed ? _path() : null;
        if (path == null) return const SizedBox.shrink();
        final card = CardSize.grid.metrics;
        final t = _controller.value;
        final travel = StageTokens.out.transform(t);
        final flip = 180 * (1 - StageTokens.inOut.transform(t));
        final turned = flip > 90;
        final center = Offset.lerp(path.deck, path.target, travel)! + Offset(0, _arc * math.sin(math.pi * t));
        return Positioned(
          left: center.dx - card.width / 2,
          top: center.dy - card.height / 2,
          child: IgnorePointer(
            child: Transform.scale(
              scale: _startScale + (1 - _startScale) * travel,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY((turned ? flip - 180 : flip) * math.pi / 180),
                child: turned ? widget.back : widget.front,
              ),
            ),
          ),
        );
      },
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
