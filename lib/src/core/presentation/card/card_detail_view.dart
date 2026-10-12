import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_detail.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/card/parts/card_detail_plaque.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Открывает полный просмотр карты [detail] поверх текущего экрана.
Future<void> showCardDetail(BuildContext context, CardDetail detail) => showGeneralDialog<void>(
  context: context,
  barrierColor: const Color(0x00000000),
  transitionDuration: CardDetailView.transitionDuration,
  pageBuilder: (context, _, _) => CardDetailView(detail: detail),
  transitionBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
);

/// Полный просмотр карты (макет карты, `cardDetailOverlay`): карта и пергамент с описанием внутри безопасной
/// зоны экрана.
///
/// Карта масштабируется в пределах 80–100 %, чтобы пергамент поместился целиком; если не помещается и при 80 %,
/// пергамент прокручивается. Закрывается тапом вне карты и пергамента или свайпом вниз дальше
/// [closeDragDistance]; пока палец тянет, подложка гаснет.
class CardDetailView extends StatefulWidget {
  /// Создаёт полный просмотр.
  const CardDetailView({super.key, required this.detail});

  /// Длительность появления и закрытия.
  static const Duration transitionDuration = Duration(milliseconds: 180);

  /// На сколько потянуть вниз, чтобы закрыть.
  static const double closeDragDistance = 90;

  /// Карта и описание.
  final CardDetail detail;

  @override
  State<CardDetailView> createState() => _CardDetailViewState();
}

class _CardDetailViewState extends State<CardDetailView> {
  double _dragOffset = 0;

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      onVerticalDragUpdate: (details) => setState(() => _dragOffset = math.max(0, _dragOffset + details.delta.dy)),
      onVerticalDragEnd: (_) {
        if (_dragOffset > CardDetailView.closeDragDistance) {
          _close();
        } else {
          setState(() => _dragOffset = 0);
        }
      },
      child: Opacity(
        opacity: math.max(0.2, 1 - _dragOffset / 300),
        child: ColoredBox(
          color: GwentColors.scrimDetail,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: CustomMultiChildLayout(
                  delegate: CardDetailLayoutDelegate(),
                  children: [
                    LayoutId(
                      id: CardDetailSlot.card,
                      child: _absorbTaps(
                        FittedBox(
                          child: GwentCard(face: widget.detail.face, size: CardSize.full),
                        ),
                      ),
                    ),
                    LayoutId(
                      id: CardDetailSlot.plaque,
                      child: _absorbTaps(CardDetailPlaque(detail: widget.detail)),
                    ),
                    LayoutId(
                      id: CardDetailSlot.hint,
                      child: Text(
                        l10n.cardDetailCloseHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: GwentText.alegreya,
                          fontSize: 12.5,
                          height: 1,
                          color: GwentColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Маршрут диалога не даёт Material: без него текст получает отладочный стиль.
    return Material(type: MaterialType.transparency, child: view);
  }

  /// Тап по карте или пергаменту не закрывает просмотр.
  static Widget _absorbTaps(Widget child) => GestureDetector(onTap: () {}, child: child);
}

/// Части полного просмотра.
enum CardDetailSlot {
  /// Карта.
  card,

  /// Пергамент с описанием.
  plaque,

  /// Подсказка о закрытии.
  hint,
}

/// Раскладка полного просмотра: колонка «карта — пергамент — подсказка» с промежутками [gap], прижатая к верху
/// безопасной зоны.
///
/// Масштаб карты k = clamp((H − 2·gap − подсказка − пергамент) / 444, 0,8, 1): пергаменту сначала отдаётся всё, что
/// останется при k = 0,8, затем карта растёт в освободившееся место. Шире экрана карта не бывает.
class CardDetailLayoutDelegate extends MultiChildLayoutDelegate {
  /// Создаёт раскладку.
  CardDetailLayoutDelegate();

  /// Промежуток между частями.
  static const double gap = 12;

  /// Ширина пергамента.
  static const double plaqueWidth = 342;

  /// Наименьший масштаб карты.
  static const double minScale = 0.8;

  @override
  void performLayout(Size size) {
    final card = CardSize.full.metrics;
    final hint = layoutChild(CardDetailSlot.hint, BoxConstraints.loose(size));
    final maxScale = math.min(1, size.width / card.width);
    final rest = size.height - 2 * gap - hint.height;
    final plaqueAvailable = math.max(0, rest - card.height * math.min(minScale, maxScale)).toDouble();
    final plaque = layoutChild(
      CardDetailSlot.plaque,
      BoxConstraints(maxWidth: math.min(plaqueWidth, size.width), maxHeight: plaqueAvailable),
    );
    final scale = ((rest - plaque.height) / card.height).clamp(math.min(minScale, maxScale), maxScale).toDouble();
    final cardSize = layoutChild(
      CardDetailSlot.card,
      BoxConstraints.tight(Size(card.width * scale, card.height * scale)),
    );
    var y = 0.0;
    positionChild(CardDetailSlot.card, Offset((size.width - cardSize.width) / 2, y));
    y += cardSize.height + gap;
    positionChild(CardDetailSlot.plaque, Offset((size.width - plaque.width) / 2, y));
    y += plaque.height + gap;
    positionChild(CardDetailSlot.hint, Offset((size.width - hint.width) / 2, y));
  }

  @override
  bool shouldRelayout(CardDetailLayoutDelegate oldDelegate) => false;
}
