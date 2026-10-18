import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

// Общие части экранов старта партии и передачи телефона (макет 4).

/// Фон экранов старта: тёмная подложка и свечения цветов фракций сверху и снизу (или одно в [centerGlow]).
class StartBackdrop extends StatelessWidget {
  /// Создаёт фон; [child] ложится поверх.
  const StartBackdrop({
    super.key,
    required this.child,
    this.topGlow,
    this.bottomGlow,
    this.centerGlow,
    this.base = const Color(0xFF0F0C09),
  });

  /// Свечение сверху.
  final Color? topGlow;

  /// Свечение снизу.
  final Color? bottomGlow;

  /// Свечение посередине.
  final Color? centerGlow;

  /// Цвет подложки.
  final Color base;

  /// Содержимое экрана.
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: base),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (topGlow case final glow?) _Glow(color: glow, alignment: Alignment.topCenter, height: 0.38),
        if (bottomGlow case final glow?) _Glow(color: glow, alignment: Alignment.bottomCenter, height: 0.38),
        if (centerGlow case final glow?) _Glow(color: glow, alignment: const Alignment(0, -0.1), height: 0.4),
        child,
      ],
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.alignment, required this.height});

  final Color color;
  final Alignment alignment;

  /// Высота эллипса в долях высоты экрана.
  final double height;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _GlowPainter(color: color, alignment: alignment, height: height),
      size: Size.infinite,
    ),
  );
}

/// Рисует эллипс-свечение шириной в 90 % экрана: цвет в центре плавно уходит в прозрачность.
class _GlowPainter extends CustomPainter {
  const _GlowPainter({required this.color, required this.alignment, required this.height});

  final Color color;
  final Alignment alignment;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final center = alignment.alongSize(size);
    final radiusX = size.width * 0.9 / 2 * 1.4;
    final radiusY = size.height * height;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(1, radiusY / radiusX)
      ..drawRect(
        Rect.fromCenter(center: Offset.zero, width: radiusX * 2, height: radiusX * 2),
        Paint()..shader = ui.Gradient.radial(Offset.zero, radiusX, [color, color.withValues(alpha: 0)], const [0, 0.7]),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.alignment != alignment || oldDelegate.height != height;
}

/// Пояснение под заголовком: Alegreya.
class StartBody extends StatelessWidget {
  /// Создаёт пояснение.
  const StartBody(
    this.text, {
    super.key,
    this.size = 15,
    this.color = GwentColors.textSecondary,
    this.align = TextAlign.center,
    this.italic = false,
  });

  /// Текст.
  final String text;

  /// Кегль.
  final double size;

  /// Цвет.
  final Color color;

  /// Выравнивание строк.
  final TextAlign align;

  /// Курсив.
  final bool italic;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    textScaler: TextScaler.noScaling,
    style: TextStyle(
      fontFamily: GwentText.alegreya,
      fontWeight: FontWeight.w500,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      fontSize: size,
      height: 1.35,
      color: color,
    ),
  );
}

/// Герб фракции [faction] и её название в строку.
class FactionLine extends StatelessWidget {
  /// Создаёт строку; [crestFirst] ставит герб перед названием.
  const FactionLine({
    super.key,
    required this.faction,
    required this.name,
    this.crestFirst = true,
    this.crestSize = 30,
    this.size = 15,
  });

  /// Фракция.
  final GwentFaction faction;

  /// Название фракции.
  final String name;

  /// Герб слева от названия.
  final bool crestFirst;

  /// Сторона герба.
  final double crestSize;

  /// Кегль названия.
  final double size;

  @override
  Widget build(BuildContext context) {
    final crest = faction.crest;
    final children = <Widget>[
      if (crest != null) GwentIconView(crest, size: crestSize),
      Flexible(
        child: Text(
          name,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: GwentText.alegreya,
            fontWeight: FontWeight.w500,
            fontSize: size,
            height: 1.1,
            color: GwentColors.textTertiary,
          ),
        ),
      ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: crestFirst ? children : children.reversed.toList(),
    );
  }
}

/// Золотая монета с тёмным диском и гербом внутри: жребий и решение Скоя'таэлей.
class FactionMedal extends StatelessWidget {
  /// Создаёт монету диаметром [size] с гербом [faction].
  const FactionMedal({super.key, required this.faction, required this.size, this.glow = false});

  /// Фракция на монете.
  final GwentFaction faction;

  /// Диаметр монеты.
  final double size;

  /// Вокруг монеты золотое свечение (итоговая медаль).
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final crest = faction.crest;
    final ring = size * 0.065;
    final inner = size - ring * 2 - 2;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.44),
          radius: 0.9,
          colors: [Color(0xFFF0D68E), GwentColors.gold, GwentColors.brass],
          stops: [0, 0.52, 1],
        ),
        boxShadow: [
          if (glow) const BoxShadow(color: Color(0x73C8A35B), blurRadius: 50),
          const BoxShadow(color: GwentColors.brassDark, spreadRadius: 3),
        ],
      ),
      child: Container(
        width: inner,
        height: inner,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GwentColors.bg,
          border: Border.all(color: GwentColors.goldHighlight),
          boxShadow: const [BoxShadow(color: GwentColors.brassDark)],
        ),
        child: crest == null ? null : GwentIconView(crest, size: size * 0.5),
      ),
    );
  }
}
