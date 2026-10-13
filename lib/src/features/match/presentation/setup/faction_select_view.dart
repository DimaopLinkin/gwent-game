import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/faction_medallion.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/domain/faction_info.dart';
import 'package:gwent/src/features/match/presentation/setup/setup_parts.dart';
import 'package:gwent/src/features/match/presentation/start/start_parts.dart';

/// Выбор фракции (макет 7, шаг 1): карусель из страниц с гербом, названием и способностью фракции.
///
/// Листается свайпом, стрелками по краям и точками внизу. Цвет фракции задаёт кольцо герба и полосу под названием.
/// Какая фракция показана, решает [index]: его хранит держатель выбора, чтобы возврат с шага лидера открывал ту же
/// страницу.
class FactionSelectView extends StatefulWidget {
  /// Создаёт экран.
  const FactionSelectView({
    super.key,
    required this.eyebrow,
    required this.factions,
    required this.index,
    required this.onIndexChanged,
    required this.onConfirm,
    required this.onBack,
    this.confirmEnabled = true,
  });

  /// Длительность перелистывания страницы стрелкой или точкой.
  static const Duration pageDuration = Duration(milliseconds: 350);

  /// Надпись над заголовком, например «Шаг 1 из 2».
  final String eyebrow;

  /// Фракции по порядку.
  final List<FactionInfo> factions;

  /// Номер показанной фракции.
  final int index;

  /// Игрок перелистнул на фракцию номер `index`.
  final ValueChanged<int> onIndexChanged;

  /// Игрок выбрал показанную фракцию.
  final VoidCallback onConfirm;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  /// Принимает ли кнопка «Выбрать фракцию» нажатие.
  final bool confirmEnabled;

  @override
  State<FactionSelectView> createState() => _FactionSelectViewState();
}

class _FactionSelectViewState extends State<FactionSelectView> {
  late final PageController _controller = PageController(initialPage: widget.index);

  /// Страница, к которой идёт перелистывание по нажатию. Пока оно идёт, промежуточные страницы не считаются выбором.
  int? _animatingTo;

  @override
  void didUpdateWidget(FactionSelectView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index || !_controller.hasClients) return;
    if ((_controller.page ?? widget.index).round() == widget.index) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _controller.jumpToPage(widget.index);
      return;
    }
    _animatingTo = widget.index;
    _controller
        .animateToPage(widget.index, duration: FactionSelectView.pageDuration, curve: Curves.easeOutCubic)
        .whenComplete(() => _animatingTo = null);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    if (_animatingTo != null && page != _animatingTo) return;
    widget.onIndexChanged(page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final last = widget.factions.length - 1;
    return SetupScaffold(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  spacing: 4,
                  children: [
                    Eyebrow(widget.eyebrow, size: 14, align: TextAlign.center),
                    StartTitle(l10n.factionSelectTitle, size: 34, color: GwentColors.goldHighlight),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                top: 0,
                child: SetupChevronButton(label: l10n.setupBack, onPressed: widget.onBack),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: widget.factions.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) => _FactionPage(faction: widget.factions[i]),
                ),
                Positioned(
                  left: 10,
                  top: 104,
                  child: SetupChevronButton(
                    label: l10n.factionSelectPrevious,
                    ring: GwentColors.brass,
                    onPressed: widget.index > 0 ? () => widget.onIndexChanged(widget.index - 1) : null,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 104,
                  child: SetupChevronButton(
                    label: l10n.factionSelectNext,
                    ring: GwentColors.brass,
                    forward: true,
                    onPressed: widget.index < last ? () => widget.onIndexChanged(widget.index + 1) : null,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 10,
              children: [
                for (var i = 0; i < widget.factions.length; i++)
                  _Dot(
                    label: widget.factions[i].name,
                    selected: i == widget.index,
                    onTap: () => widget.onIndexChanged(i),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: SizedBox(
              width: double.infinity,
              child: GwentButton(
                label: l10n.factionSelectConfirm,
                onPressed: widget.confirmEnabled ? widget.onConfirm : null,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Страница карусели: герб, название, полоса цвета, способность. На низком экране прокручивается.
class _FactionPage extends StatelessWidget {
  const _FactionPage({required this.faction});

  final FactionInfo faction;

  @override
  Widget build(BuildContext context) {
    final gwent = GwentFaction.fromKey(faction.key);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 8),
      child: Column(
        children: [
          FactionMedallion(faction: gwent, size: 232, crestSize: 170, band: 5, innerLine: true),
          const SizedBox(height: 22),
          Text(
            faction.name,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 36,
              height: 1.05,
              color: GwentColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(color: gwent.accent, borderRadius: BorderRadius.circular(2)),
            child: const SizedBox(width: 72, height: 4),
          ),
          if (faction.perk.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _PerkLabel(),
            const SizedBox(height: 10),
            Text(
              faction.perk,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.alegreya,
                fontSize: 19,
                height: 1.4,
                color: GwentColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PerkLabel extends StatelessWidget {
  const _PerkLabel();

  @override
  Widget build(BuildContext context) => SetupPanelLabel(context.l10n.factionSelectPerk);
}

/// Точка-ромб под каруселью; зона нажатия 24×24 pt.
class _Dot extends StatelessWidget {
  const _Dot({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 24,
        child: Center(
          child: DiamondMarker(
            size: selected ? 12 : 8,
            color: selected ? GwentColors.goldHighlight : GwentColors.muted,
          ),
        ),
      ),
    ),
  );
}
