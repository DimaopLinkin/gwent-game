import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/start/start_parts.dart';

// Общие части экранов выбора фракции, лидера и колоды перед партией (макет 7).

/// Основа экрана выбора: фон стола и безопасные зоны. Сверху остаётся отступ 14 pt под строку состояния.
class SetupScaffold extends StatelessWidget {
  /// Создаёт основу; [child] ложится в безопасную область.
  const SetupScaffold({super.key, required this.child});

  /// Содержимое экрана.
  final Widget child;

  @override
  Widget build(BuildContext context) => ScreenBackdrop(
    child: SafeArea(
      child: Padding(padding: const EdgeInsets.only(top: 14), child: child),
    ),
  );
}

/// Круглая кнопка со стрелкой-шевроном: «назад» в шапке и стрелки карусели фракций. Зона нажатия 44×44 pt.
class SetupChevronButton extends StatelessWidget {
  /// Создаёт кнопку; без [onPressed] она погашена.
  const SetupChevronButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.forward = false,
    this.ring = GwentColors.muted,
  });

  /// Подпись для экранного диктора.
  final String label;

  /// Нажатие; `null` — кнопка погашена (треть яркости).
  final VoidCallback? onPressed;

  /// Стрелка вправо; иначе влево.
  final bool forward;

  /// Цвет кольца.
  final Color ring;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    onTap: onPressed,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.3 : 1,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xEB14110E),
            border: Border.all(color: ring),
          ),
          child: CustomPaint(painter: _ChevronPainter(forward: forward)),
        ),
      ),
    ),
  );
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.forward});

  final bool forward;

  @override
  void paint(Canvas canvas, Size size) {
    // Шеврон из макета: 8 pt в ширину и 16 в высоту вокруг центра круга.
    final c = size.center(Offset.zero);
    final dx = forward ? -4.0 : 4.0;
    final path = Path()
      ..moveTo(c.dx + dx, c.dy - 8)
      ..lineTo(c.dx - dx, c.dy)
      ..lineTo(c.dx + dx, c.dy + 8);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = GwentColors.goldHighlight,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.forward != forward;
}

/// Шапка шага: кнопка «назад», надпись над заголовком, заголовок и необязательная подпись; справа [trailing].
class SetupHeader extends StatelessWidget {
  /// Создаёт шапку.
  const SetupHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.trailing,
    this.titleSize = 30,
  });

  /// Надпись над заголовком, например «Шаг 2 из 2».
  final String eyebrow;

  /// Заголовок.
  final String title;

  /// Подпись под заголовком, например название фракции.
  final String? subtitle;

  /// Что стоит справа, например герб фракции.
  final Widget? trailing;

  /// Размер заголовка.
  final double titleSize;

  /// Нажатие «назад».
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      SetupChevronButton(label: context.l10n.setupBack, onPressed: onBack),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 5,
          children: [
            Eyebrow(eyebrow),
            StartTitle(title, size: titleSize, color: GwentColors.goldHighlight),
            if (subtitle != null) StartBody(subtitle!, color: GwentColors.textTertiary, italic: true),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

/// Метка-«бирка»: короткая надпись Cormorant SC на плотной подложке («Доступен», «Готова», «Колода не готова»).
class SetupTag extends StatelessWidget {
  /// Создаёт метку.
  const SetupTag(this.text, {super.key, required this.background, required this.color, this.ring});

  /// Текст.
  final String text;

  /// Цвет подложки.
  final Color background;

  /// Цвет текста.
  final Color color;

  /// Цвет тонкой рамки или `null`, если рамки нет.
  final Color? ring;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(3),
      border: ring == null ? null : Border.all(color: ring!),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: GwentText.cormorant,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.1,
          letterSpacing: 12 * 0.05,
          color: color,
        ),
      ),
    ),
  );
}

/// Ромб-метка (выбранная колода, цвет фракции): квадрат, повёрнутый на 45°, с тёмным кантом.
class DiamondMarker extends StatelessWidget {
  /// Создаёт ромб со стороной [size].
  const DiamondMarker({super.key, required this.size, required this.color, this.glow});

  /// Сторона квадрата до поворота.
  final double size;

  /// Заливка.
  final Color color;

  /// Цвет свечения вокруг ромба или `null`.
  final Color? glow;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: math.pi / 4,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        boxShadow: [
          const BoxShadow(color: GwentColors.bg, spreadRadius: 1),
          if (glow != null) BoxShadow(color: glow!, blurRadius: 10),
        ],
      ),
      child: SizedBox.square(dimension: size),
    ),
  );
}

/// Панель с рамкой для текста способности (фон `#14110E` 92 %, рамка линии).
class SetupPanel extends StatelessWidget {
  /// Создаёт панель.
  const SetupPanel({super.key, required this.child, this.minHeight = 0});

  /// Содержимое.
  final Widget child;

  /// Минимальная высота.
  final double minHeight;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: minHeight),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xEB14110E),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: GwentColors.line),
    ),
    child: child,
  );
}

/// Надпись над текстом в панели: Alegreya 12 pt, прописные, разрядка 14 %.
class SetupPanelLabel extends StatelessWidget {
  /// Создаёт надпись.
  const SetupPanelLabel(this.text, {super.key});

  /// Текст.
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textScaler: TextScaler.noScaling,
    style: const TextStyle(
      fontFamily: GwentText.alegreya,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      height: 1,
      letterSpacing: 12 * 0.14,
      color: GwentColors.textSecondary,
    ),
  );
}

/// Делит полное имя лидера по первому двоеточию: «Фольтест: Король Темерии» → («Фольтест», «Король Темерии»).
/// Без двоеточия второй части нет.
(String, String?) splitLeaderName(String name) {
  final i = name.indexOf(': ');
  return i > 0 ? (name.substring(0, i), name.substring(i + 2)) : (name, null);
}

/// Короткое имя лидера для строки списка: персонаж и первая часть прозвища до запятой,
/// «Эмгыр вар Эмрейс: Белое Пламя, Пляшущее на Курганах Врагов» → «Эмгыр вар Эмрейс, Белое Пламя».
String shortLeaderName(String name) {
  final (character, nickname) = splitLeaderName(name);
  return nickname == null ? character : '$character, ${nickname.split(',').first}';
}
