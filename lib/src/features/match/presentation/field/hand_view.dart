import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/features/match/presentation/field/drag_feedback.dart';
import 'package:gwent/src/features/match/presentation/field/field_geometry.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Карта руки для рисования: экземпляр, лицо и можно ли её сыграть сейчас.
typedef HandCard = ({CardInstance instance, CardFace face, bool enabled});

/// Рука игрока (макет поля, «Рука · два варианта»): веер или горизонтальная прокрутка.
///
/// Веер по умолчанию: шаг карт `min(81, (W − 56 − 77) / (n − 1))`, поворот до ±10°, края дуги подняты, поля от
/// краёв экрана 28 pt, чтобы повёрнутые крайние карты и скругления экрана не срезали медальоны. Когда шаг меньше
/// 25 pt (12 карт и больше на экране 390 pt, 11 и больше на 360 pt), веер заменяется прокруткой с картами целиком; её
/// листают и за сами карты (горизонтальный сдвиг), а вертикальный тянет карту на цель. Тап выбирает карту, долгое нажатие открывает просмотр, а сдвиг
/// на 8 pt (в режиме прокрутки вертикальный, около 18 pt) начинает перетаскивание: под пальцем идёт мини-карта
/// (`DragFeedback`), цели ловят `DragTarget<CardInstance>`.
class HandView extends StatefulWidget {
  /// Создаёт руку.
  const HandView({
    super.key,
    required this.geometry,
    required this.cards,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.hover,
    this.hidden = const {},
    this.cardKeys,
  });

  /// Размеры зон поля.
  final FieldGeometry geometry;

  /// Карты слева направо.
  final List<HandCard> cards;

  /// Выбранная карта.
  final CardInstanceId? selected;

  /// Тап по карте.
  final void Function(HandCard card) onTap;

  /// Долгое нажатие по карте.
  final void Function(HandCard card) onLongPress;

  /// Карту начали тащить.
  final void Function(HandCard card) onDragStarted;

  /// Карту отпустили: [accepted] — её принял `DragTarget`, иначе она вернулась в руку.
  final void Function(HandCard card, {required bool accepted}) onDragEnded;

  /// Палец с картой над целью: от этого зависит яркость карты под пальцем.
  final ValueListenable<bool> hover;

  /// Карты, которые ещё летят в руку (анимации карт): место занято, карты не видно.
  final Set<CardInstanceId> hidden;

  /// Метки карт: по ним слой урока находит, где карта лежит сейчас (с поворотом веера, подъёмом и прокруткой). Если не
  /// заданы, рука держит свои.
  final Map<CardInstanceId, GlobalKey>? cardKeys;

  /// Точка касания в перетаскиваемом виджете: палец в центре `DragFeedback`, мини-карта рядом с ним.
  static const Offset dragAnchor = Offset(DragFeedback.side / 2, DragFeedback.side / 2);

  /// Верх карт веера на краях дуги; в центре карты ниже на [arcDepth].
  static const double fanTop = 16;

  /// Глубина дуги веера.
  static const double arcDepth = 8;

  @override
  State<HandView> createState() => _HandViewState();
}

class _HandViewState extends State<HandView> {
  final Map<CardInstanceId, GlobalKey> _ownKeys = {};

  Map<CardInstanceId, GlobalKey> get _keys => widget.cardKeys ?? _ownKeys;

  /// Где палец, пока карту тащат; `null`, когда не тащат.
  final ValueNotifier<Offset?> _pointer = ValueNotifier(null);

  @override
  void didUpdateWidget(HandView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selected;
    if (selected != null && selected != oldWidget.selected && widget.geometry.handScrolls(widget.cards.length)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _keys[selected]?.currentContext;
        if (context != null && context.mounted) {
          unawaited(Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 180), alignment: 0.5));
        }
      });
    }
  }

  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.geometry.handScrolls(widget.cards.length) ? _scroll() : _fan();

  Widget _fan() {
    final geometry = widget.geometry;
    final cards = widget.cards;
    final count = cards.length;
    final center = (count - 1) / 2;
    final step = geometry.fanStep(count);
    const inset = FieldGeometry.fanInset;
    final left = inset + (geometry.width - 2 * inset - (77 + (count - 1) * step)) / 2;
    final rotationStep = count > 1 ? math.min(2.2, 16 / (count - 1)) : 0.0;
    // Спуск до центральной карты: вокруг неё остальные карты поднимаются к краям.
    final extra = (geometry.handHeight - FieldGeometry.minHandHeight) / 2;
    final order = [
      for (var i = 0; i < count; i++)
        if (cards[i].instance.id != widget.selected) i,
      for (var i = 0; i < count; i++)
        if (cards[i].instance.id == widget.selected) i,
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final i in order)
          AnimatedPositioned(
            key: ValueKey(cards[i].instance.id),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: (left + i * step).roundToDouble(),
            top: extra + _top(i, center, cards[i]),
            width: 77,
            height: 111,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 180),
              turns: cards[i].instance.id == widget.selected ? 0 : (i - center) * rotationStep / 360,
              alignment: const Alignment(0, 1.8),
              child: KeyedSubtree(
                key: _keys.putIfAbsent(cards[i].instance.id, GlobalKey.new),
                child: _draggable(cards[i], affinity: null),
              ),
            ),
          ),
      ],
    );
  }

  double _top(int index, double center, HandCard card) {
    if (card.instance.id == widget.selected) return HandView.fanTop;
    if (center == 0) return HandView.fanTop + HandView.arcDepth;
    final distance = (index - center) / center;
    return HandView.fanTop + HandView.arcDepth * (1 - distance * distance);
  }

  Widget _scroll() {
    final cards = widget.cards;
    return Stack(
      children: [
        Positioned.fill(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(10, 16, 22, 0),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) => KeyedSubtree(
              key: _keys.putIfAbsent(cards[i].instance.id, GlobalKey.new),
              child: Align(
                alignment: Alignment.topCenter,
                child: _draggable(cards[i], affinity: Axis.vertical),
              ),
            ),
          ),
        ),
        const Positioned(left: 0, top: 0, bottom: 0, width: 14, child: _EdgeFade(toRight: true)),
        const Positioned(right: 0, top: 0, bottom: 0, width: 22, child: _EdgeFade(toRight: false)),
      ],
    );
  }

  Widget _draggable(HandCard card, {required Axis? affinity}) {
    final child = _card(card, affinity: affinity);
    if (!widget.hidden.contains(card.instance.id)) return child;
    return IgnorePointer(child: Opacity(opacity: 0, child: child));
  }

  Widget _card(HandCard card, {required Axis? affinity}) {
    final selected = card.instance.id == widget.selected;
    final face = GwentCard(
      face: card.face,
      size: CardSize.hand,
      highlight: !card.enabled
          ? CardHighlight.disabled
          : selected
          ? CardHighlight.selected
          : CardHighlight.normal,
      onTap: () => widget.onTap(card),
      onLongPress: () => widget.onLongPress(card),
    );
    if (!card.enabled) return face;
    return Draggable<CardInstance>(
      data: card.instance,
      // Без affinity Draggable забирает жест сразу при касании и рука не листается за карты: с ней он ждёт движения
      // по своей оси, а горизонтальный сдвиг достаётся списку. Ось самой карты не ограничена: начав вверх, её водят
      // по полю куда угодно (так же играют Чучело и карты на ряд соперника).
      affinity: affinity,
      dragAnchorStrategy: (_, _, position) {
        _pointer.value = position;
        return HandView.dragAnchor;
      },
      onDragStarted: () => widget.onDragStarted(card),
      onDragUpdate: (details) => _pointer.value = details.globalPosition,
      onDragEnd: (details) {
        _pointer.value = null;
        widget.onDragEnded(card, accepted: details.wasAccepted);
      },
      feedback: DragFeedback(face: card.face, over: widget.hover, pointer: _pointer),
      childWhenDragging: Opacity(opacity: 0.35, child: face),
      child: face,
    );
  }
}

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.toRight});

  final bool toRight;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: toRight ? Alignment.centerLeft : Alignment.centerRight,
          end: toRight ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [Color(0xFF17120E), Color(0x0017120E)],
        ),
      ),
    ),
  );
}
