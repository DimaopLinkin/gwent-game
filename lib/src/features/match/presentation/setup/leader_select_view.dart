import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/card/leader_name.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/info_panel.dart';
import 'package:gwent/src/core/presentation/components/status_tag.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/domain/faction_info.dart';
import 'package:gwent/src/features/match/presentation/setup/setup_parts.dart';

/// Выбор лидера выбранной фракции (макет 7, шаг 2): выбранный лидер крупно с описанием способности и сетка карт.
///
/// Лидеры, которых нет в коллекции, приглушены и с замком, кнопка для них погашена. Длинные имена делятся по
/// двоеточию на два ряда: персонаж и прозвище. Сетка прокручивается, нижний край уходит в тень.
class LeaderSelectView extends StatelessWidget {
  /// Создаёт экран.
  const LeaderSelectView({
    super.key,
    required this.eyebrow,
    required this.faction,
    required this.selectedId,
    required this.faceOf,
    required this.onSelect,
    required this.onConfirm,
    required this.onBack,
    this.busy = false,
  });

  /// Надпись над заголовком, например «Шаг 2 из 2».
  final String eyebrow;

  /// Фракция, чьих лидеров выбирают.
  final FactionInfo faction;

  /// UUID выбранного лидера.
  final String? selectedId;

  /// Лицо карты лидера с UUID `leaderId`.
  final CardFace Function(String leaderId) faceOf;

  /// Игрок выбрал лидера с UUID `leaderId`.
  final ValueChanged<String> onSelect;

  /// Игрок подтвердил выбранного лидера.
  final VoidCallback onConfirm;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  /// Идёт подготовка колод: кнопка не принимает нажатий.
  final bool busy;

  /// Доступная высота, с которой сетка лидеров стоит на месте, а не прокручивается вместе с картой.
  static const double _minHeightForFixedGrid = 740;

  /// Выбранный лидер и описание его способности.
  List<Widget> _selectedBlock(AppLocalizations l10n, LeaderInfo selected) => [
    const SizedBox(height: 16),
    _SelectedLeader(leader: selected, face: faceOf(selected.id)),
    const SizedBox(height: 14),
    InfoPanel(
      minHeight: 84,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          InfoPanelLabel(l10n.leaderSelectAbility),
          SizedBox(
            width: double.infinity,
            child: Text(
              selected.ability,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.alegreya,
                fontSize: 17,
                height: 1.35,
                color: GwentColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gwent = GwentFaction.fromKey(faction.key);
    final selected = selectedId == null ? null : faction.leader(selectedId!);
    // Шапка, карта, способность и кнопка занимают около 500 pt; сетке нужна хотя бы строка карт и запас под вторую.
    // Если доступной высоты (без системных панелей) меньше, всё это прокручивается, а кнопка остаётся внизу.
    final media = MediaQuery.of(context);
    final compact = media.size.height - media.padding.vertical < _minHeightForFixedGrid;
    final available = selected?.available ?? false;
    final canConfirm = available && !busy;
    return SetupScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
        child: Column(
          children: [
            SetupHeader(
              eyebrow: eyebrow,
              title: l10n.leaderSelectTitle,
              subtitle: faction.name,
              onBack: onBack,
              trailing: gwent.crest == null ? null : GwentIconView(gwent.crest!, size: 40),
            ),
            if (compact)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (selected != null) ..._selectedBlock(l10n, selected),
                      const SizedBox(height: 14),
                      _LeaderGrid(
                        faction: faction,
                        selectedId: selectedId,
                        faceOf: faceOf,
                        onSelect: onSelect,
                        scrollable: false,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (selected != null) ..._selectedBlock(l10n, selected),
              const SizedBox(height: 14),
              Expanded(
                child: _LeaderGrid(faction: faction, selectedId: selectedId, faceOf: faceOf, onSelect: onSelect),
              ),
            ],
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: GwentButton(
                label: available ? l10n.leaderSelectConfirm : l10n.leaderSelectUnavailable,
                onPressed: canConfirm ? onConfirm : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Выбранный лидер: карта в полтора раза крупнее сетки, справа имя в два ряда и метка доступности.
class _SelectedLeader extends StatelessWidget {
  const _SelectedLeader({required this.leader, required this.face});

  /// Размер выбранной карты: сетка 103×148, увеличенная в 1,6 раза.
  static const double _width = 165;
  static const double _height = 237;

  final LeaderInfo leader;
  final CardFace face;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (name, nickname) = splitLeaderName(leader.name);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        SizedBox(
          width: _width,
          height: _height,
          child: FittedBox(
            child: GwentCard(
              face: face,
              size: CardSize.grid,
              highlight: leader.available ? CardHighlight.normal : CardHighlight.disabled,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                name,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w700,
                  fontSize: 21,
                  height: 1.1,
                  color: GwentColors.textPrimary,
                ),
              ),
              if (nickname != null)
                Text(
                  nickname,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                    height: 1.2,
                    color: GwentColors.textSecondary,
                  ),
                ),
              StatusTag(
                leader.available ? l10n.leaderStatusAvailable : l10n.leaderStatusLocked,
                background: leader.available ? GwentColors.gold : GwentColors.surfaceRaised,
                color: leader.available ? GwentColors.onGold : GwentColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Сетка карт лидеров: до трёх в ряд по центру, прокрутка, нижний край уходит в тень.
class _LeaderGrid extends StatelessWidget {
  const _LeaderGrid({
    required this.faction,
    required this.selectedId,
    required this.faceOf,
    required this.onSelect,
    this.scrollable = true,
  });

  final FactionInfo faction;
  final String? selectedId;
  final CardFace Function(String leaderId) faceOf;
  final ValueChanged<String> onSelect;

  /// Прокручивается ли сетка сама и уходит ли её нижний край в тень; иначе её прокручивает родитель.
  final bool scrollable;

  Widget _wrap() => Center(
    child: ConstrainedBox(
      // Три карты и два промежутка по 18 pt: четвёртая уходит во второй ряд.
      constraints: const BoxConstraints(maxWidth: 3 * 103 + 2 * 18),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 14,
        children: [
          for (final leader in faction.leaders)
            _LeaderTile(
              leader: leader,
              face: faceOf(leader.id),
              selected: leader.id == selectedId,
              onTap: () => onSelect(leader.id),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => !scrollable
      ? Padding(padding: const EdgeInsets.only(bottom: 12), child: _wrap())
      : ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
            stops: [0, 0.8, 1],
          ).createShader(bounds),
          child: SingleChildScrollView(padding: const EdgeInsets.only(top: 10, bottom: 70), child: _wrap()),
        );
}

class _LeaderTile extends StatelessWidget {
  const _LeaderTile({required this.leader, required this.face, required this.selected, required this.onTap});

  final LeaderInfo leader;
  final CardFace face;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 103,
    height: 148,
    child: Opacity(
      opacity: leader.available ? 1 : 0.85,
      child: Stack(
        children: [
          GwentCard(
            face: face,
            size: CardSize.grid,
            highlight: switch ((selected, leader.available)) {
              (true, _) => CardHighlight.selected,
              (false, true) => CardHighlight.normal,
              (false, false) => CardHighlight.disabled,
            },
            // Недоступного лидера тоже можно открыть, чтобы прочитать способность; подтвердить его нельзя.
            onTap: onTap,
          ),
          if (!leader.available) const Positioned(left: 32.5, top: 44, child: IgnorePointer(child: _Lock())),
        ],
      ),
    ),
  );
}

/// Замок на недоступном лидере: тёмный круг 38 pt с тонким кольцом.
class _Lock extends StatelessWidget {
  const _Lock();

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xE00E0B09),
      border: Border.all(color: GwentColors.muted),
    ),
    child: CustomPaint(painter: _LockPainter()),
  );
}

class _LockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()..color = GwentColors.textSecondary;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c.translate(0, 3), width: 14, height: 10.5),
          const Radius.circular(1.5),
        ),
        paint,
      )
      ..drawArc(
        Rect.fromCenter(center: c.translate(0, -2.5), width: 8, height: 9),
        3.14159,
        3.14159,
        false,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_LockPainter oldDelegate) => false;
}
