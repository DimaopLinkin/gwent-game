import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/faction_medallion.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/campaign/application/load_card_book.dart';
import 'package:gwent/src/features/campaign/domain/card_book.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_widgets.dart';
import 'package:gwent/src/features/campaign/presentation/card_book_cubit.dart';
import 'package:gwent/src/features/campaign/presentation/card_book_state.dart';

/// Название раздела книги: фракция из пакета или «Общие карты».
String bookSectionName(BuildContext context, LoadedCardBook loaded, BookSection section) {
  final fraction = section.fractionId == null ? null : loaded.data.pack.rules.fractionsById[section.fractionId];
  return fraction == null ? context.l10n.campaignBookCommon : loaded.data.text(fraction.nameKey);
}

/// «Книга карт», обзор: общее кольцо «открыто из всего» и строки разделов с полосой прогресса. Нулевые фракции видны,
/// чтобы был виден масштаб, но приглушены.
///
/// Ждёт `CardBookCubit` выше по дереву.
class CardBookScreen extends StatelessWidget {
  /// Создаёт экран; [onOpenSection] получает идентификатор раздела (`BookSection.id`).
  const CardBookScreen({super.key, required this.onBack, required this.onOpenSection});

  /// Назад на тропу.
  final VoidCallback onBack;

  /// Открыть раздел.
  final ValueChanged<String> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: Column(
        children: [
          ScreenHeader(title: l10n.campaignBookTitle, onBack: onBack),
          Expanded(
            child: BlocBuilder<CardBookCubit, CardBookState>(
              builder: (context, state) => switch (state) {
                CardBookLoading() => const GameLoader(),
                CardBookUnavailable() => Center(child: Text(l10n.campaignBookUnavailable)),
                CardBookReady(:final loaded) => _Overview(loaded: loaded, onOpenSection: onOpenSection),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.loaded, required this.onOpenSection});

  final LoadedCardBook loaded;
  final ValueChanged<String> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final book = loaded.book;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _TotalPlate(opened: book.opened, total: book.total),
        for (final section in book.sections)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _SectionRow(
              loaded: loaded,
              section: section,
              onTap: () => onOpenSection(section.id),
            ),
          ),
      ],
    );
  }
}

class _TotalPlate extends StatelessWidget {
  const _TotalPlate({required this.opened, required this.total});

  final int opened;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GwentColors.rowSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GwentColors.panelLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          spacing: 16,
          children: [
            Semantics(
              label: l10n.campaignBookRowCount(opened, total),
              excludeSemantics: true,
              child: SizedBox.square(
                dimension: 84,
                child: CustomPaint(
                  painter: _RingPainter(total == 0 ? 0 : opened / total),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$opened',
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: GwentText.cormorant,
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                            height: 1,
                            color: GwentColors.textPrimary,
                          ),
                        ),
                        Text(
                          l10n.campaignBookOutOf(total),
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: GwentText.alegreya,
                            fontSize: 11,
                            color: GwentColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                l10n.campaignBookNote,
                style: const TextStyle(fontFamily: GwentText.alegreya, fontSize: 15, color: GwentColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 6.0;
    final rect = (Offset.zero & size).deflate(width / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = GwentColors.panelLine;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (fraction <= 0) return;
    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = GwentColors.gold;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction.clamp(0.0, 1.0), false, value);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.loaded, required this.section, required this.onTap});

  final LoadedCardBook loaded;
  final BookSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = bookSectionName(context, loaded, section);
    final count = l10n.campaignBookRowCount(section.opened, section.total);
    final touched = section.opened > 0;
    return Semantics(
      button: true,
      label: l10n.campaignBookRowLabel(name, count),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: touched ? 1 : 0.65,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: GwentColors.rowSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: GwentColors.panelLine),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                spacing: 12,
                children: [
                  if (section.fractionId == null)
                    const SizedBox.square(
                      dimension: 48,
                      child: Center(child: GwentIconView(GwentIcon.iconDeck, size: 28)),
                    )
                  else
                    FactionMedallion(
                      faction: factionLook(loaded.data.pack.rules, section.fractionId),
                      size: 48,
                      crestSize: 26,
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        Row(
                          spacing: 8,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textScaler: TextScaler.noScaling,
                                style: const TextStyle(
                                  fontFamily: GwentText.cormorant,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  height: 1.1,
                                  color: GwentColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              count,
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontFamily: GwentText.cormorant,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: touched ? GwentColors.gold : GwentColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        _Bar(fraction: section.total == 0 ? 0 : section.opened / section.total),
                      ],
                    ),
                  ),
                  const Text(
                    '›',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: 24, color: GwentColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: SizedBox(
      height: 6,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: GwentColors.panelLine)),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: const ColoredBox(color: GwentColors.gold),
          ),
        ],
      ),
    ),
  );
}
