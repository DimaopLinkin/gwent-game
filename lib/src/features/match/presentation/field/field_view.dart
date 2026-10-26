import 'dart:async';

import 'package:flutter/widgets.dart' hide Intent, Row;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_detail_view.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/components/confirm_dialog.dart';
import 'package:gwent/src/core/presentation/components/game_toast.dart';
import 'package:gwent/src/core/presentation/components/pass_button.dart';
import 'package:gwent/src/core/presentation/components/pause_button.dart';
import 'package:gwent/src/core/presentation/components/player_bar.dart';
import 'package:gwent/src/core/presentation/components/rolling_number.dart';
import 'package:gwent/src/core/presentation/components/weather_strip.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/field/banner_layer.dart';
import 'package:gwent/src/features/match/presentation/field/drag_hover.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_geometry.dart';
import 'package:gwent/src/features/match/presentation/field/field_lesson.dart';
import 'package:gwent/src/features/match/presentation/field/field_overlays.dart';
import 'package:gwent/src/features/match/presentation/field/field_row_view.dart';
import 'package:gwent/src/features/match/presentation/field/field_sheets.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/match/presentation/field/hand_view.dart';
import 'package:gwent/src/features/match/presentation/field/lifted_card.dart';
import 'package:gwent/src/features/match/presentation/field/play_targets.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match/presentation/overlays/pause_layers.dart';
import 'package:gwent/src/features/match/presentation/overlays/round_summary_view.dart';
import 'package:gwent/src/features/match/presentation/overlays/rules_view.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_frame.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_geometry.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_host.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_layer.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_script.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Игровое поле (макеты поля и оверлеев): ряды соперника, центральная полоса, мои ряды, полосы игроков и рука.
///
/// Рисует проекцию [view] глазами игрока, который держит телефон, и отдаёт его ходы в [onIntent]. Что игрок выбрал
/// и какой лист открыл, хранит `FieldCubit` из контекста. Поле строится на холсте шириной экрана и высотой
/// бюджета макета (751 pt); на низких экранах холст уменьшается целиком, на высоких лишнее достаётся руке.
///
/// Поверх поля идут баннеры раунда, хода и паса, итог раунда и слои паузы (меню, правила, подтверждение сдачи).
/// Системная кнопка «назад» закрывает лист или снимает выбор, а на чистом поле открывает паузу: выйти из партии можно
/// только сдавшись.
class FieldView extends StatefulWidget {
  /// Создаёт поле.
  const FieldView({
    super.key,
    required this.view,
    required this.content,
    required this.roster,
    required this.onIntent,
    this.confirmPass = false,
    this.hints = false,
    this.onSettings,
    this.readOnly = false,
    this.opponentStatus,
    this.lesson,
  });

  /// Проекция партии.
  final PlayerView view;

  /// Контент партии: по нему рисуются карты.
  final GameContent content;

  /// Участники партии: по ним называются игроки.
  final MatchRoster roster;

  /// Ход игрока уходит в партию.
  final ValueChanged<Intent> onIntent;

  /// Спрашивать подтверждение паса диалогом; иначе пас нужно держать 1 с.
  final bool confirmPass;

  /// Показывать подсказку, что делать с выбранной картой, в центральной полосе (настройка «Подсказки»).
  final bool hints;

  /// Открыть настройки поверх партии из меню паузы; `null` — кнопка «Настройки» недоступна.
  final VoidCallback? onSettings;

  /// Поле только смотрят (за листом итога матча, в реплее): ходов нет, пауза и пас недоступны, системная «назад»
  /// не открывает паузу, а уходит дальше. Просмотр карт, сброса и лидера остаётся.
  final bool readOnly;

  /// Индикатор в полосе соперника (связь в сетевой партии, ADR 0019); `null` — индикатора нет.
  final Widget? opponentStatus;

  /// Урок поверх поля («Первая партия», ADR 0034): слой подсказок и своё меню паузы; `null` — обычная партия.
  final FieldLesson? lesson;

  @override
  State<FieldView> createState() => _FieldViewState();
}

class _FieldViewState extends State<FieldView> {
  static const RowView _emptyRow = RowView(cards: [], slot: null, weather: false, strength: 0);

  FieldContent? _content;
  AppLocalizations? _l10n;

  /// Метка холста и меток полос игроков: по ним анимации карт находят места на полосах.
  final GlobalKey _canvasKey = GlobalKey();
  final Map<CardInstanceId, GlobalKey> _handKeys = {};
  final Map<bool, PlayerBarAnchors> _anchors = {true: PlayerBarAnchors(), false: PlayerBarAnchors()};

  /// Как полоса погоды называет себя перед `DragHover`.
  static const Object _stripTarget = 'strip';

  /// Над какой целью палец с картой: яркость карты под пальцем и вибрация входа и выхода (макет 14).
  late final DragHover _hover = DragHover(
    onChanged: ({required over}) => _cubit.vibrate(over ? TargetHaptics.enter : TargetHaptics.leave),
    onSwitched: () => _cubit.vibrate(TargetHaptics.enter),
  );

  /// Карту тащат по-настоящему (цели есть, ход можно делать) и выбор поставило само перетаскивание.
  bool _dragStarted = false;
  bool _selectedByDrag = false;
  StageGeometry? _stageGeometry;
  int? _stageGeometryScript;
  double? _stageGeometryWidth;

  /// Поле экрана; пока идёт последний ход раунда, поле до подсчёта (экран уже получил поле после уборки).
  PlayerView get _view => _cubit.state.stage?.board ?? widget.view;
  FieldCubit get _cubit => context.read<FieldCubit>();

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureContent();
  }

  @override
  void didUpdateWidget(FieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureContent();
  }

  void _ensureContent() {
    final l10n = context.l10n;
    if (_content == null || !identical(_content!.content, widget.content) || !identical(_l10n, l10n)) {
      _l10n = l10n;
      _content = FieldContent(content: widget.content, l10n: l10n);
    }
  }

  /// Ход мой; выбор движка его не прерывает.
  static bool _turnIsMine(PlayerView view) =>
      view.phase == MatchPhase.playing && view.turn == view.viewer && !view.me.passed;

  /// Можно ходить прямо сейчас: ход мой и движок не ждёт выбора.
  static bool _isMyTurn(PlayerView view) => _turnIsMine(view) && view.choice == null;

  FieldContent get _fieldContent => _content!;

  /// Поле что-то показывает (баннер хода, итог раунда, конец партии): начинать ход пока нельзя. Просмотр листов,
  /// пауза и ответы на выбор движка этим не закрываются.
  bool get _blocked => _cubit.state.isBusy;

  CardCatalog get _catalog => widget.content.catalog;

  PlayTargets _targets(FieldState field) {
    final selected = field.selected;
    if (selected == null || _view.choice != null) return PlayTargets.none;
    final card = _view.me.hand?.where((card) => card.id == selected).firstOrNull;
    return card == null ? PlayTargets.none : PlayTargets.forCard(_view, card, _catalog);
  }

  Set<Row> _choiceRows() {
    final choice = _view.choice;
    if (choice == null || choice.kind != ChoiceKind.unitRow) return const {};
    return {
      for (final option in choice.options)
        if (option is RowOption) option.row,
    };
  }

  void _play(Intent intent) {
    if (_blocked || widget.readOnly) return;
    _cubit
      ..vibrate(TargetHaptics.hit)
      ..clearSelected();
    widget.onIntent(intent);
  }

  /// Нажатие не по цели снимает выбор карты (макет 14); у карты на всё поле (погода) целью служит любая зона поля.
  void _tapElsewhere(FieldState field) {
    if (field.selected != null) _cubit.clearSelected();
  }

  void _tapRow(Row row, {required bool mine, required FieldState field}) {
    if (widget.readOnly) return;
    if (mine && _choiceRows().contains(row)) {
      widget.onIntent(ChooseOption(RowOption(row)));
      return;
    }
    // Погоду, Ясное небо и Казнь тапом играют только по центральной полосе, остальные ряды и карты тап снимает выбор:
    // случайный тап по полю не должен разыграть необратимую Казнь. Броском эти карты принимает всё поле.
    if (_targets(field).atRow(row, mine: mine) case final intent?) {
      _play(intent);
    } else {
      _tapElsewhere(field);
    }
  }

  void _tapStrip(FieldState field) {
    if (widget.readOnly) return;
    if (_targets(field).atStrip() case final intent?) {
      _play(intent);
    } else {
      _tapElsewhere(field);
    }
  }

  void _tapFieldCard(CardInstance card, Row row, {required bool mine, required FieldState field}) {
    final intent = mine ? _targets(field).atFieldCard(card.id) : null;
    if (intent != null) {
      _play(intent);
    } else {
      _tapRow(row, mine: mine, field: field);
    }
  }

  void _tapHandCard(HandCard card) {
    final view = _view;
    if (view.choice != null || _blocked || widget.readOnly) return;
    final cubit = _cubit;
    if (view.me.passed) {
      cubit.say(FieldMessage.alreadyPassed);
    } else if (view.turn != view.viewer) {
      cubit.say(FieldMessage.opponentTurn);
    } else if (!card.enabled || PlayTargets.forCard(view, card.instance, _catalog).isEmpty) {
      cubit.say(FieldMessage.cardNotPlayable);
    } else {
      cubit.toggleSelected(card.instance.id);
    }
  }

  void _startDrag(HandCard card) {
    _hover.reset();
    _dragStarted = false;
    if (_blocked || widget.readOnly) return;
    if (PlayTargets.forCard(_view, card.instance, _catalog).isEmpty) return;
    _dragStarted = true;
    _selectedByDrag = _cubit.state.selected != card.instance.id;
    _cubit.select(card.instance.id);
  }

  void _showDetail(CardInstance card, {int? power, bool frosted = false}) {
    unawaited(showCardDetail(context, _fieldContent.detail(card, power: power, frosted: frosted)));
  }

  Future<void> _pass() async {
    if (_blocked || widget.readOnly) return;
    _cubit.clearSelected();
    if (!widget.confirmPass) {
      widget.onIntent(const Pass());
      return;
    }
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.passConfirmTitle,
      body: l10n.passConfirmBody(_view.me.handCount),
      confirmLabel: l10n.passButtonLabel,
    );
    if (confirmed && mounted) widget.onIntent(const Pass());
  }

  bool _canDrop(CardInstance card, {required Row row, required bool mine}) =>
      !widget.readOnly && !_blocked && PlayTargets.forCard(_view, card, _catalog).atRow(row, mine: mine) != null;

  void _drop(CardInstance card, {required Row row, required bool mine}) {
    if (PlayTargets.forCard(_view, card, _catalog).atRow(row, mine: mine) case final intent?) _play(intent);
  }

  /// Захваченный Чучелом отряд, приподнятый над рядом (макет 14); без захвата ничего не рисует.
  Widget _liftedCard(FieldGeometry geometry) => ValueListenableBuilder<Object?>(
    valueListenable: _hover.target,
    builder: (context, target, _) {
      // Показ розыгрыша посреди наведения убирает зоны без сообщения о выходе: подъёма над перестроенным рядом нет.
      if (target is! CardTarget || _blocked) return const SizedBox.shrink();
      for (final MapEntry(key: row, value: rowView) in _view.me.rows.entries) {
        final index = rowView.cards.indexWhere((view) => view.card.id == target.card);
        if (index < 0) continue;
        final view = rowView.cards[index];
        final face = _fieldContent
            .detail(
              view.card,
              power: view.strength,
              frosted: rowView.weather && row == Row.melee,
            )
            .face;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            LiftedCard(
              key: ValueKey(target.card),
              face: face,
              rect: geometry.cardRect(row, index, rowView.cards.length, mine: true),
            ),
          ],
        );
      }
      return const SizedBox.shrink();
    },
  );

  bool _canDropOnCard(CardInstance card, CardInstance target) =>
      !widget.readOnly && !_blocked && PlayTargets.forCard(_view, card, _catalog).atFieldCard(target.id) != null;

  void _dropOnCard(CardInstance card, CardInstance target) {
    if (PlayTargets.forCard(_view, card, _catalog).atFieldCard(target.id) case final intent?) _play(intent);
  }

  /// Карту отпустили: мимо цели она вернулась в руку, о чём игрок узнаёт по двум коротким вибрациям.
  void _dragEnded(HandCard card, {required bool accepted}) {
    _hover.reset();
    if (!_dragStarted || accepted) return;
    _cubit.vibrate(TargetHaptics.miss);
    // Выбор поставило само перетаскивание: карта вернулась в руку, и подсветка с подсказкой уходят вместе с ней.
    if (_selectedByDrag && _cubit.state.selected == card.instance.id) _cubit.clearSelected();
  }

  void _onBack(FieldState field) {
    final cubit = _cubit;
    if (field.pause != PauseLayer.none) {
      if (field.pause == PauseLayer.menu) {
        cubit.closePause();
      } else {
        cubit.backToPauseMenu();
      }
    } else if (field.summary != null) {
      cubit.dismissSummary();
    } else if (field.overlay is! NoOverlay || field.selected != null) {
      cubit
        ..closeOverlay()
        ..clearSelected();
    } else {
      cubit.openPause();
    }
  }

  void _surrender() {
    _cubit.closePause();
    widget.onIntent(const Resign());
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<FieldCubit, FieldState>(
    builder: (context, field) {
      final sheet = _sheet(context, field);
      return PopScope(
        canPop: widget.readOnly,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack(field);
        },
        child: Stack(
          children: [
            // Слои идут на весь экран, включая зоны под вырезом и жестом «домой»; поле лежит в безопасной области.
            const Positioned.fill(child: _FieldBackdrop()),
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fit = FieldFit(constraints.maxWidth, constraints.maxHeight);
                    final geometry = fit.geometry;
                    return FittedBox(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: fit.width,
                        height: fit.height,
                        child: StageHost(
                          script: field.stage,
                          onDone: _cubit.endStage,
                          onCue: _cubit.playSound,
                          builder: (context, frame, speedUp, skip) =>
                              _canvas(context, geometry, field, frame, speedUp, skip),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            ?sheet,
            if (field.summary case final summary?)
              Positioned.fill(
                child: RoundSummaryView(
                  summary: summary,
                  roster: widget.roster,
                  onDismissed: _cubit.dismissSummary,
                ),
              ),
            if (widget.lesson case final lesson?)
              Positioned.fill(
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) => lesson.layerBuilder(
                      context,
                      FieldLayout(
                        fit: FieldFit(constraints.maxWidth, constraints.maxHeight),
                        field: field,
                        view: _view,
                        hand: _fieldContent.handOrder(_view.me.hand ?? const <CardInstance>[]).toList(),
                        anchors: _anchors,
                        handKeys: _handKeys,
                      ),
                    ),
                  ),
                ),
              ),
            ?_pauseLayer(field),
          ],
        ),
      );
    },
  );

  Widget? _pauseLayer(FieldState field) {
    final cubit = _cubit;
    return switch (field.pause) {
      PauseLayer.none => null,
      PauseLayer.menu => Positioned.fill(
        child: PauseMenuLayer(
          onResume: cubit.closePause,
          onRules: cubit.openRules,
          onSettings: widget.onSettings,
          onSurrender: cubit.askSurrender,
          onRestart: widget.lesson?.onRestart,
          onExit: widget.lesson?.onExit,
        ),
      ),
      PauseLayer.rules => Positioned.fill(
        child: RulesView(roster: widget.roster, onBack: cubit.backToPauseMenu),
      ),
      PauseLayer.surrenderConfirm => Positioned.fill(
        child: SurrenderConfirmLayer(onCancel: cubit.backToPauseMenu, onConfirm: _surrender),
      ),
    };
  }

  /// Перевод мест сценария в координаты холста; пока идёт один сценарий, помнит места исчезнувших карт.
  StageGeometry _stageGeometryFor(FieldGeometry geometry, StageScript script) {
    final cached = _stageGeometry;
    if (cached != null && _stageGeometryScript == script.id && _stageGeometryWidth == geometry.width) return cached;
    _stageGeometryScript = script.id;
    _stageGeometryWidth = geometry.width;
    return _stageGeometry = StageGeometry(
      field: geometry,
      canvas: _canvasKey,
      anchors: _anchors,
      projection: _view,
    );
  }

  Widget _stageLayer(FieldGeometry geometry, StageScript script, StageFrame frame) {
    final view = _view;
    CardFace back({required bool mine}) =>
        CardBackFace(faction: _fieldContent.faction((mine ? view.me : view.opponent).faction));
    CardFace leader({required bool mine}) => _fieldContent.leaderFace((mine ? view.me : view.opponent).leader);
    return StageLayer(
      frame: frame,
      geometry: _stageGeometryFor(geometry, script),
      faceOf: _fieldContent.face,
      backOf: back,
      leaderOf: leader,
      roster: widget.roster,
      content: _fieldContent,
    );
  }

  Widget _canvas(
    BuildContext context,
    FieldGeometry geometry,
    FieldState field,
    StageFrame? frame,
    VoidCallback speedUp,
    VoidCallback skip,
  ) {
    final l10n = context.l10n;
    final view = _view;
    final me = view.me;
    final opponent = view.opponent;
    final targets = _targets(field);
    final choiceRows = _choiceRows();
    final hint = _hintText(l10n, targets);
    final script = field.stage;
    return KeyedSubtree(
      key: _canvasKey,
      child: ColoredBox(
        color: GwentColors.bg,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final mine in const [false, true])
              for (final row in Row.values)
                FieldRowView(
                  key: ValueKey((mine, row)),
                  geometry: geometry,
                  content: _fieldContent,
                  row: row,
                  mine: mine,
                  data: (mine ? me : opponent).rows[row] ?? _emptyRow,
                  isTarget: targets.highlightsRow(row, mine: mine) || (mine && choiceRows.contains(row)),
                  hornTarget: targets.highlightsHornSlot(row),
                  hornLabel: _isHorn(targets) ? l10n.fieldHornGhostLabel : null,
                  decoyTargets: mine && targets.kind == PlayTargetKind.decoy ? targets.fieldCards : const {},
                  recent: field.recent,
                  staged: frame?.rows[(mine: mine, row: row)],
                  strengthRoll: frame?.counters[(kind: StageCounter.rowScore, mine: mine, row: row)],
                  flashes: frame?.flashes ?? const {},
                  onTap: () => _tapRow(row, mine: mine, field: field),
                  canDrop: (card) => _canDrop(card, row: row, mine: mine),
                  onDrop: (card) => _drop(card, row: row, mine: mine),
                  onCardTap: (card) => _tapFieldCard(card, row, mine: mine, field: field),
                  onDragEnter: _hover.enter,
                  onDragLeave: _hover.leave,
                  canDropOnCard: _canDropOnCard,
                  onDropOnCard: _dropOnCard,
                  onCardLongPress: (card, strength) => _showDetail(
                    card,
                    power: strength,
                    frosted: (mine ? me : opponent).rows[row]?.weather == true && row == Row.melee,
                  ),
                ),
            Positioned.fromRect(rect: geometry.strip, child: _strip(l10n, field, targets, frame, hint)),
            if (targets.highlightsStrip)
              Positioned.fromRect(
                rect: geometry.scrimArea,
                child: DragTarget<CardInstance>(
                  onWillAcceptWithDetails: (details) {
                    final accepts =
                        !widget.readOnly &&
                        !_blocked &&
                        PlayTargets.forCard(view, details.data, _catalog).highlightsStrip;
                    if (accepts) _hover.enter(_stripTarget);
                    return accepts;
                  },
                  onLeave: (_) => _hover.leave(_stripTarget),
                  onAcceptWithDetails: (details) {
                    if (PlayTargets.forCard(view, details.data, _catalog).atStrip() case final intent?) _play(intent);
                  },
                  builder: (context, candidates, _) => Stack(
                    children: [
                      TargetHighlight(look: candidates.isNotEmpty ? TargetLook.hot : TargetLook.candidate),
                    ],
                  ),
                ),
              ),
            Positioned.fromRect(
              rect: geometry.opponentBar,
              child: _bar(l10n, mine: false, frame: frame),
            ),
            Positioned.fromRect(
              rect: geometry.myBar,
              child: _bar(l10n, mine: true, frame: frame),
            ),
            Positioned.fill(child: _liftedCard(geometry)),
            Positioned.fromRect(
              rect: geometry.hand,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF17120E), GwentColors.bg],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: HandView(
                        geometry: geometry,
                        cards: [
                          for (final card in _fieldContent.handOrder(me.hand ?? const <CardInstance>[]))
                            if (!(frame?.handAbsent.contains(card.id) ?? false))
                              (instance: card, face: _fieldContent.face(card), enabled: me.playable.contains(card.id)),
                        ],
                        selected: field.selected,
                        onTap: _tapHandCard,
                        onLongPress: (card) => _showDetail(card.instance),
                        onDragStarted: _startDrag,
                        onDragEnded: _dragEnded,
                        hover: _hover,
                        hidden: frame?.handHidden ?? const {},
                        cardKeys: _handKeys,
                      ),
                    ),
                    if (frame != null && frame.handVeil > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(color: GwentColors.bg.withValues(alpha: 0.5 * frame.handVeil)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (frame != null && script != null) ...[
              Positioned.fill(child: _stageLayer(geometry, script, frame)),
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: speedUp),
              ),
              if (script.steps.length > 1)
                Positioned(
                  top: geometry.hand.top + 4,
                  right: 8,
                  child: _SkipButton(onPressed: skip),
                ),
            ],
            if (!widget.readOnly)
              Positioned.fromRect(
                rect: geometry.pauseButtonRect,
                child: PauseButton(onPressed: _cubit.openPause, semanticsLabel: l10n.pauseButtonSemantics),
              ),
            if (field.summary == null && field.pause == PauseLayer.none && field.stage == null)
              Positioned.fill(
                child: BannerLayer(
                  banner: field.banners.firstOrNull,
                  roster: widget.roster,
                  onDismissed: _cubit.dismissBanner,
                ),
              ),
            if (field.toast case final toast?)
              Positioned(
                left: 16,
                right: 16,
                top: FieldGeometry.barHeight + 8,
                child: _ToastHost(
                  key: ValueKey(toast.id),
                  onExpired: () => _cubit.clearToast(toast.id),
                  child: GameToast(
                    message: _toastText(l10n, toast.message),
                    icon: toast.isError ? GwentIcon.iconLifeGemLost : GwentIcon.iconHand,
                    isError: toast.isError,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _strip(AppLocalizations l10n, FieldState field, PlayTargets targets, StageFrame? frame, String? hint) {
    final view = _view;
    final (status, active) = switch (view) {
      PlayerView(phase: MatchPhase.finished) => (l10n.fieldStatusMatchOver, false),
      PlayerView(choice: != null) => (l10n.fieldStatusYourChoice, true),
      PlayerView(opponentChoosing: != null) => (l10n.fieldStatusOpponentChoosing, false),
      PlayerView(me: SideView(passed: true)) => (l10n.fieldStatusYouPassed, false),
      _ when view.turn == view.viewer => (l10n.bannerYourTurn, true),
      _ => (l10n.fieldStatusOpponentTurn, false),
    };
    // Подсчёт, плашка итога и плашка исхода занимают середину полосы: статус под ними только мешал бы.
    final covered = frame?.items.any((item) => item is CountItem || item is PlaqueItem || item is MatchBannerItem);
    // Пока идёт показ последних ходов партии, «Партия окончена» не пишется: она появляется после них.
    final hidden = covered == true || (view.phase == MatchPhase.finished && field.stage != null);
    return WeatherStrip(
      slots: [
        for (final row in Row.values)
          (
            rowIcon: FieldContent.rowIcon(row),
            weather: (frame?.weatherSlots[row] ?? view.me.rows[row]?.weather == true)
                ? FieldContent.weatherOf(row)
                : null,
          ),
      ],
      status: hidden ? '' : status,
      hint: hidden ? null : hint,
      statusActive: active,
      round: view.round,
      isTarget: targets.highlightsStrip,
      onTap: () => _tapStrip(field),
      showPauseSlot: true,
    );
  }

  Widget _bar(AppLocalizations l10n, {required bool mine, StageFrame? frame}) {
    final view = _view;
    final side = mine ? view.me : view.opponent;
    final other = mine ? view.opponent : view.me;
    final discardTop = frame != null && frame.discardTops.containsKey(mine)
        ? frame.discardTops[mine]
        : side.discard.lastOrNull;
    RollValue? roll(StageCounter kind) => frame?.counters[(kind: kind, mine: mine, row: null)];
    int? otherScore(StageFrame? frame) => frame?.counters[(kind: StageCounter.total, mine: !mine, row: null)]?.nearest;
    final cubit = _cubit;
    final canPass = _isMyTurn(view) && !_blocked && !widget.readOnly;
    return Transform.translate(
      offset: Offset(frame?.shakes[mine] ?? 0, 0),
      child: PlayerBar(
        mine: mine,
        name: widget.roster.name(mine ? view.viewer : view.viewer.opponent, l10n),
        faction: _fieldContent.faction(side.faction),
        leader: _fieldContent.leaderFace(side.leader, used: frame?.leaderUsed[mine] ?? side.leaderUsed),
        leaderAvailable: mine && side.leaderAvailable && canPass,
        lifeRemaining: frame?.gems[mine]?.remaining ?? side.crystals,
        lifeBreak: frame?.gems[mine]?.progress,
        handCount: side.handCount,
        score: side.score,
        leading: (roll(StageCounter.total)?.nearest ?? side.score) > (otherScore(frame) ?? other.score),
        deckCount: side.deckCount,
        discardCount: side.discard.length,
        discardTop: discardTop == null ? null : _fieldContent.face(discardTop),
        scoreRoll: roll(StageCounter.total),
        handRoll: roll(StageCounter.hand),
        deckRoll: roll(StageCounter.deck),
        discardRoll: roll(StageCounter.discard),
        anchors: _anchors[mine],
        status: mine ? null : widget.opponentStatus,
        // Пока движок ждёт выбора, листы игрока не открываются: они остались бы под листом выбора.
        onLeaderTap: view.choice == null ? () => cubit.openLeader(mine: mine) : null,
        onLeaderLongPress: view.choice == null ? () => cubit.openLeader(mine: mine) : null,
        onDiscardTap: view.choice == null ? () => cubit.openDiscard(mine: mine) : null,
        trailing: mine
            ? PassButton(
                compact: true,
                enabled: canPass,
                holdToPass: !widget.confirmPass,
                onPressed: () => unawaited(_pass()),
              )
            : side.passed
            ? _PassedTag(label: l10n.fieldPassedTag)
            : null,
      ),
    );
  }

  bool _isHorn(PlayTargets targets) =>
      targets.card != null && _fieldContent.special(targets.card!)?.ability is HornCardAbility;

  /// Статичная подсказка в центральной полосе (макет 14): общая инструкция по виду карты, она не меняется от положения
  /// пальца и не называет результат. `null` — подсказки выключены или выбирать нечего.
  String? _hintText(AppLocalizations l10n, PlayTargets targets) {
    if (!widget.hints || widget.readOnly) return null;
    final choice = _view.choice;
    if (choice != null) return choice.kind == ChoiceKind.unitRow ? l10n.fieldHintUnitRow : null;
    return switch (targets.kind) {
      PlayTargetKind.none => null,
      PlayTargetKind.ownRow => targets.rows.length > 1 ? l10n.fieldHintAgile : l10n.fieldHintOwnRow,
      PlayTargetKind.opponentRow => l10n.fieldHintSpy,
      PlayTargetKind.hornSlot => _isHorn(targets) ? l10n.fieldHintHorn : l10n.fieldHintMardrem,
      PlayTargetKind.strip => l10n.fieldHintStrip,
      PlayTargetKind.decoy => l10n.fieldHintDecoy,
    };
  }

  String _toastText(AppLocalizations l10n, FieldMessage message) => switch (message) {
    FieldMessage.opponentTurn => l10n.fieldToastOpponentTurn,
    FieldMessage.alreadyPassed => l10n.fieldToastAlreadyPassed,
    FieldMessage.cardNotPlayable => l10n.fieldToastCardNotPlayable,
    FieldMessage.refused => l10n.fieldToastRefused,
  };

  // Листы поверх поля.

  Widget? _sheet(BuildContext context, FieldState field) {
    // Листы выбора ждут конца показа: иначе они закрыли бы карту, которая ещё летит.
    if (field.stage != null) return null;
    final l10n = context.l10n;
    final choice = _view.choice;
    if (choice != null) {
      return switch (choice.kind) {
        ChoiceKind.firstPlayer || ChoiceKind.unitRow => null,
        ChoiceKind.medicTarget ||
        ChoiceKind.opponentDiscardCard ||
        ChoiceKind.ownDiscardCard ||
        ChoiceKind.handCardToDiscard ||
        ChoiceKind.deckCard ||
        ChoiceKind.deckWeather => _choiceSheet(l10n, choice),
      };
    }
    return switch (field.overlay) {
      NoOverlay() => null,
      DiscardOverlay(:final mine) => _discardSheet(l10n, field, mine: mine),
      LeaderOverlay(:final mine) => _leaderSheet(l10n, mine: mine),
      RevealOverlay(:final cards) => CardGridSheet(
        title: l10n.fieldRevealTitle,
        subtitle: l10n.fieldRevealSubtitle,
        cards: [for (final card in cards) _gridCard(card)],
        buttons: [SheetButton(label: l10n.fieldRevealDone, primary: true, onPressed: _cubit.closeOverlay)],
        onClose: _cubit.closeOverlay,
      ),
    };
  }

  GridCard _gridCard(CardInstance card, {VoidCallback? onTap}) => (
    id: card.id,
    face: _fieldContent.face(card),
    highlighted: onTap != null,
    disabled: false,
    onTap: onTap,
    onLongPress: () => _showDetail(card),
  );

  Widget _choiceSheet(AppLocalizations l10n, PendingChoice choice) {
    final title = switch (choice.kind) {
      ChoiceKind.medicTarget => l10n.fieldChoiceMedic,
      ChoiceKind.opponentDiscardCard => l10n.fieldChoiceOpponentDiscard,
      ChoiceKind.ownDiscardCard => l10n.fieldChoiceOwnDiscard,
      ChoiceKind.handCardToDiscard => l10n.fieldChoiceHandDiscard,
      ChoiceKind.deckCard => l10n.fieldChoiceDeckCard,
      ChoiceKind.deckWeather => l10n.fieldChoiceDeckWeather,
      ChoiceKind.firstPlayer || ChoiceKind.unitRow => '',
    };
    return CardGridSheet(
      title: title,
      subtitle: l10n.fieldChoiceSubtitle,
      note: l10n.fieldChoiceNoCancel,
      cards: [
        for (final option in choice.options)
          if (option is CardOption) _gridCard(option.card, onTap: () => widget.onIntent(ChooseOption(option))),
      ],
    );
  }

  Widget _discardSheet(AppLocalizations l10n, FieldState field, {required bool mine}) {
    final side = mine ? _view.me : _view.opponent;
    final latestFirst = side.discard.reversed.toList();
    final cards = switch (field.sort) {
      DiscardSort.byOrder => latestFirst,
      DiscardSort.byStrength => _byStrength(latestFirst),
    };
    final cubit = _cubit;
    return CardGridSheet(
      title: mine ? l10n.fieldDiscardMine : l10n.fieldDiscardOpponent,
      subtitle: l10n.fieldDiscardSubtitle(cards.length),
      sorts: [
        (
          label: l10n.fieldSortStrength,
          selected: field.sort == DiscardSort.byStrength,
          onTap: () => cubit.setSort(DiscardSort.byStrength),
        ),
        (
          label: l10n.fieldSortOrder,
          selected: field.sort == DiscardSort.byOrder,
          onTap: () => cubit.setSort(DiscardSort.byOrder),
        ),
      ],
      cards: [for (final card in cards) _gridCard(card)],
      emptyTitle: l10n.fieldDiscardEmptyTitle,
      emptyText: l10n.fieldDiscardEmptyText,
      buttons: [SheetButton(label: l10n.fieldClose, onPressed: cubit.closeOverlay)],
      onClose: cubit.closeOverlay,
    );
  }

  List<CardInstance> _byStrength(List<CardInstance> cards) {
    final indexed = [for (var i = 0; i < cards.length; i++) (index: i, card: cards[i])];
    indexed.sort((a, b) {
      final byStrength = _fieldContent.baseStrength(b.card).compareTo(_fieldContent.baseStrength(a.card));
      return byStrength != 0 ? byStrength : a.index.compareTo(b.index);
    });
    return [for (final entry in indexed) entry.card];
  }

  Widget _leaderSheet(AppLocalizations l10n, {required bool mine}) {
    final view = _view;
    final side = mine ? view.me : view.opponent;
    final cubit = _cubit;
    final canUse = mine && side.leaderAvailable && _isMyTurn(view) && !_blocked;
    // Пассивная способность действует постоянно: использовать её нельзя, кнопки нет.
    final passive = _catalog.leader(side.leader)?.ability.isPassive ?? false;
    final note = passive
        ? l10n.fieldLeaderPassiveNote
        : side.leaderUsed
        ? l10n.fieldLeaderUsedNote
        : side.leaderDisabled
        ? l10n.fieldLeaderDisabledNote
        : mine && !canUse
        ? l10n.fieldLeaderWaitNote
        : null;
    return LeaderSheet(
      detail: _fieldContent.leader(side.leader, used: side.leaderUsed),
      note: note,
      buttons: [
        if (mine && !passive)
          SheetButton(
            label: l10n.fieldLeaderUse,
            primary: true,
            onPressed: canUse
                ? () {
                    cubit.closeOverlay();
                    widget.onIntent(const UseLeader());
                  }
                : null,
          ),
        SheetButton(label: l10n.fieldClose, onPressed: cubit.closeOverlay),
      ],
      onClose: cubit.closeOverlay,
    );
  }
}

/// Фон за полем на весь экран: под вырезом он продолжает полосу соперника, под жестом «домой» — руку, поэтому в
/// безопасных зонах нет швов.
class _FieldBackdrop extends StatelessWidget {
  const _FieldBackdrop();

  /// Верхний цвет полосы соперника (`PlayerBar`).
  static const Color topColor = Color(0xFF1B1612);

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: GwentColors.bg,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: MediaQuery.paddingOf(context).top,
        width: double.infinity,
        child: const ColoredBox(color: topColor),
      ),
    ),
  );
}

/// Метка «Спасовал» на полосе соперника: 70×30 pt, пока соперник вышел из раунда.
class _PassedTag extends StatelessWidget {
  const _PassedTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 70,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: GwentColors.brass),
    ),
    child: Text(
      label,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
      style: GwentText.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5, height: 1),
    ),
  );
}

/// Убирает тост по истечении [GameToast.visibleFor].
class _ToastHost extends StatefulWidget {
  const _ToastHost({super.key, required this.onExpired, required this.child});

  final VoidCallback onExpired;
  final Widget child;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(GameToast.visibleFor, widget.onExpired);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(child: widget.child);
}

/// Кнопка «Пропустить» в углу поля: переходит к следующему шагу показа конца раунда или матча.
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.stageSkip,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: GwentColors.bg.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: GwentColors.brass),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Text(
                context.l10n.stageSkip,
                textScaler: TextScaler.noScaling,
                style: GwentText.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
