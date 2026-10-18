import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_detail.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent_engine/gwent_engine.dart' show CardInstanceId;

/// Карта в сетке листа: экземпляр, лицо и что делают нажатия.
typedef GridCard = ({
  CardInstanceId id,
  CardFace face,
  bool highlighted,
  bool disabled,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
});

/// Кнопка внизу листа (макет оверлеев): пилюля 48 pt; главная с двойной рамкой, вторая только с контуром.
@immutable
class SheetButton {
  /// Создаёт кнопку.
  const SheetButton({required this.label, required this.onPressed, this.primary = false});

  /// Подпись.
  final String label;

  /// Нажатие; `null` — кнопка неактивна.
  final VoidCallback? onPressed;

  /// Главное действие листа.
  final bool primary;
}

/// Вкладка сортировки сетки.
typedef SheetSort = ({String label, bool selected, VoidCallback onTap});

/// Подложка и панель листа, выезжающего снизу (макет оверлеев): затемнение 72 %, панель со скруглением 16 pt и
/// ручкой. Тап по затемнению вызывает [onClose]; без него лист закрыть нельзя (ответ на выбор движка).
class SheetFrame extends StatelessWidget {
  /// Создаёт лист вокруг [child].
  const SheetFrame({super.key, required this.child, this.onClose, this.maxHeightFactor = 0.62});

  /// Содержимое под ручкой.
  final Widget child;

  /// Закрытие тапом по затемнению.
  final VoidCallback? onClose;

  /// Предельная высота листа в долях высоты поля.
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    // Лист идёт на весь экран: затемнение и панель доходят до краёв, содержимое панели отступает от жеста «домой».
    final insets = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const ColoredBox(color: Color(0xB80A0806)),
          ),
        ),
        // Панель прижата к низу и не выше доли высоты поля: Positioned.fill даёт LayoutBuilder настоящую высоту поля.
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) => Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  maxWidth: constraints.maxWidth,
                  maxHeight: (constraints.maxHeight - insets.vertical) * maxHeightFactor + insets.bottom,
                ),
                // Тап по самой панели не закрывает лист.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [GwentColors.surfaceRaised, GwentColors.surface],
                      ),
                      boxShadow: [
                        BoxShadow(color: Color(0x99000000), offset: Offset(0, -10), blurRadius: 30),
                        BoxShadow(color: GwentColors.brass, spreadRadius: 1),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14) + EdgeInsets.only(bottom: insets.bottom),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 12,
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: GwentColors.muted,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Flexible(child: child),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Лист с сеткой карт 103×148 (макет оверлеев): сброс, медик, выбор из колоды, рука соперника.
class CardGridSheet extends StatelessWidget {
  /// Создаёт лист.
  const CardGridSheet({
    super.key,
    required this.title,
    required this.cards,
    this.subtitle,
    this.note,
    this.sorts = const [],
    this.buttons = const [],
    this.emptyTitle,
    this.emptyText,
    this.onClose,
    this.gridHeight = 352,
  });

  /// Заголовок.
  final String title;

  /// Пояснение под заголовком.
  final String? subtitle;

  /// Мелкая заметка под сеткой.
  final String? note;

  /// Карты сетки.
  final List<GridCard> cards;

  /// Вкладки сортировки; пусто — без вкладок.
  final List<SheetSort> sorts;

  /// Кнопки внизу.
  final List<SheetButton> buttons;

  /// Заголовок пустого листа.
  final String? emptyTitle;

  /// Пояснение пустого листа.
  final String? emptyText;

  /// Закрытие тапом по затемнению.
  final VoidCallback? onClose;

  /// Наибольшая высота сетки.
  final double gridHeight;

  @override
  Widget build(BuildContext context) => SheetFrame(
    onClose: onClose,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 5,
            children: [
              Text(title, style: GwentText.title.copyWith(fontSize: 22, height: 1.1)),
              if (subtitle != null) Text(subtitle!, style: GwentText.caption.copyWith(height: 1.3)),
            ],
          ),
          if (sorts.isNotEmpty) _SortTabs(sorts: sorts),
          if (cards.isNotEmpty)
            _Grid(cards: cards, height: gridHeight)
          else if (emptyTitle != null)
            _Empty(title: emptyTitle!, text: emptyText),
          if (note != null)
            Text(
              note!,
              textAlign: TextAlign.center,
              style: GwentText.caption.copyWith(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                fontSize: 12.5,
              ),
            ),
          if (buttons.isNotEmpty) SheetButtons(buttons: buttons),
        ],
      ),
    ),
  );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.cards, required this.height});

  final List<GridCard> cards;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final spacing = (constraints.maxWidth - 3 * CardMetrics.grid.width) / 2;
      final rows = (cards.length / 3).ceil();
      final contentHeight = rows * CardMetrics.grid.height + (rows - 1) * 12 + 3;
      return SizedBox(
        height: contentHeight < height ? contentHeight : height,
        child: Stack(
          children: [
            GridView.builder(
              padding: const EdgeInsets.only(top: 3),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: CardMetrics.grid.height,
                crossAxisSpacing: spacing < 0 ? 0 : spacing,
                mainAxisSpacing: 12,
              ),
              itemCount: cards.length,
              itemBuilder: (context, i) {
                final card = cards[i];
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: card.highlighted
                        ? const [
                            BoxShadow(color: Color(0x80C8A35B), blurRadius: 14),
                            BoxShadow(color: GwentColors.gold, spreadRadius: 2),
                          ]
                        : null,
                  ),
                  child: GwentCard(
                    face: card.face,
                    size: CardSize.grid,
                    highlight: card.disabled ? CardHighlight.disabled : CardHighlight.normal,
                    onTap: card.onTap,
                    onLongPress: card.onLongPress,
                  ),
                );
              },
            ),
            if (contentHeight > height)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 26,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00221C16), GwentColors.surface],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _SortTabs extends StatelessWidget {
  const _SortTabs({required this.sorts});

  final List<SheetSort> sorts;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: GwentColors.bg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: GwentColors.line),
    ),
    child: Row(
      spacing: 4,
      children: [
        for (final sort in sorts)
          Expanded(
            child: Semantics(
              button: true,
              selected: sort.selected,
              label: sort.label,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: sort.onTap,
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: sort.selected
                        ? const RadialGradient(
                            center: Alignment(0, -0.4),
                            radius: 1.2,
                            colors: [GwentColors.surfaceWarm, Color(0xFF2A2119)],
                            stops: [0, 0.7],
                          )
                        : null,
                    border: sort.selected ? Border.all(color: GwentColors.gold) : null,
                  ),
                  child: Text(
                    sort.label,
                    textScaler: TextScaler.noScaling,
                    style: GwentText.label.copyWith(
                      fontSize: 15,
                      letterSpacing: 0.6,
                      color: sort.selected ? GwentColors.goldHighlight : GwentColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, this.text});

  final String title;
  final String? text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 28, 12, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: GwentColors.bg,
            boxShadow: [BoxShadow(color: GwentColors.muted, spreadRadius: 1)],
          ),
          child: const GwentIconView(GwentIcon.iconDiscard, size: 30, color: GwentColors.muted),
        ),
        Text(title, textAlign: TextAlign.center, style: GwentText.title.copyWith(fontSize: 22, height: 1.1)),
        if (text != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              text!,
              textAlign: TextAlign.center,
              style: GwentText.caption.copyWith(fontSize: 14.5, height: 1.4),
            ),
          ),
      ],
    ),
  );
}

/// Ряд кнопок внизу листа или диалога.
class SheetButtons extends StatelessWidget {
  /// Создаёт ряд из [buttons].
  const SheetButtons({super.key, required this.buttons});

  /// Кнопки слева направо.
  final List<SheetButton> buttons;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 10,
    children: [for (final button in buttons) Expanded(child: _Button(button: button))],
  );
}

class _Button extends StatelessWidget {
  const _Button({required this.button});

  final SheetButton button;

  @override
  Widget build(BuildContext context) {
    final enabled = button.onPressed != null;
    final primary = button.primary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: button.label,
      excludeSemantics: true,
      onTap: button.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: button.onPressed,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: primary && enabled
                ? const RadialGradient(
                    center: Alignment(0, -0.4),
                    radius: 1.1,
                    colors: [GwentColors.surfaceWarm, GwentColors.surface],
                    stops: [0, 0.7],
                  )
                : null,
            color: primary && !enabled ? GwentColors.panel : null,
            // Кольцо у кнопок без заливки рисует рамка: тень в Flutter заливала бы всю прозрачную кнопку.
            border: primary && enabled ? null : Border.all(color: primary ? GwentColors.line : GwentColors.muted),
            boxShadow: [
              if (primary && enabled) ...const [
                BoxShadow(color: Color(0x47C8A35B), blurRadius: 14),
                BoxShadow(color: GwentColors.gold, spreadRadius: 1.5),
              ],
            ],
          ),
          child: Text(
            button.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: GwentText.label.copyWith(
              fontSize: 19,
              letterSpacing: 0.95,
              color: enabled ? GwentColors.textPrimary : GwentColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Лист лидера (макет оверлеев, раздел «Лидер»): полная карта, способность и кнопки.
class LeaderSheet extends StatelessWidget {
  /// Создаёт лист лидера [detail].
  const LeaderSheet({super.key, required this.detail, required this.buttons, this.note, this.onClose});

  /// Лидер и его способность.
  final CardDetail detail;

  /// Пояснение под способностью: «использована» или «отключена».
  final String? note;

  /// Кнопки.
  final List<SheetButton> buttons;

  /// Закрытие тапом по затемнению.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final ability = detail.abilities.isEmpty ? null : detail.abilities.first;
    return SheetFrame(
      onClose: onClose,
      maxHeightFactor: 0.96,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Center(
              child: GwentCard(face: detail.face, size: CardSize.full),
            ),
            if (ability != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: Alignment(-0.2, -0.36),
                          radius: 0.9,
                          colors: [GwentColors.brassHighlight, GwentColors.brassLight, GwentColors.brassDark],
                          stops: [0, 0.58, 1],
                        ),
                        boxShadow: [BoxShadow(color: GwentColors.brassDeep, spreadRadius: 1)],
                      ),
                      child: GwentIconView(
                        ability.icon,
                        size: 18,
                        color: GwentColors.onGold,
                        cutColor: GwentColors.brassCut,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 3,
                        children: [
                          Text(
                            ability.name,
                            style: GwentText.body.copyWith(fontWeight: FontWeight.w700, fontSize: 15, height: 1.2),
                          ),
                          Text(
                            ability.description,
                            style: GwentText.body.copyWith(fontSize: 14.5, height: 1.4, color: const Color(0xFFCFC3A8)),
                          ),
                          if (note != null)
                            Text(
                              note!,
                              style: GwentText.caption.copyWith(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w400,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            SheetButtons(buttons: buttons),
          ],
        ),
      ),
    );
  }
}
