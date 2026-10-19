import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/faction_medallion.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/status_tag.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent_net/gwent_net.dart' show LobbyStage;

/// Ожидание соперника у хоста (макет 9, экран 2b): кольца пульсируют, пока партия видна в сети.
class RoomWaiting extends StatefulWidget {
  /// Создаёт ожидание партии [title]; [onShowQr] открывает QR-код партии, [onCancel] закрывает партию.
  const RoomWaiting({super.key, required this.title, required this.onShowQr, required this.onCancel});

  /// Название партии.
  final String title;

  /// Игрок хочет показать QR-код партии.
  final VoidCallback onShowQr;

  /// Игрок отменил партию.
  final VoidCallback onCancel;

  @override
  State<RoomWaiting> createState() => _RoomWaitingState();
}

class _RoomWaitingState extends State<RoomWaiting> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 0.4;
    } else if (!_pulse.isAnimating) {
      unawaited(_pulse.repeat());
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 14,
                  children: [
                    SizedBox.square(
                      dimension: 180,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => CustomPaint(
                          painter: _RingsPainter(_pulse.value),
                          child: const Center(
                            child: GwentIconView(GwentIcon.iconWifi, size: 52, color: GwentColors.goldHighlight),
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.netWaitTitle,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 30,
                          color: GwentColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      l10n.netWaitYourGame,
                      style: const TextStyle(
                        fontFamily: GwentText.alegreya,
                        fontSize: 14,
                        color: GwentColors.textSecondary,
                      ),
                    ),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: GwentText.cormorant,
                        fontWeight: FontWeight.w700,
                        fontSize: 26,
                        color: GwentColors.goldHighlight,
                      ),
                    ),
                    Text(
                      l10n.netWifiOneNetwork,
                      style: const TextStyle(
                        fontFamily: GwentText.alegreya,
                        fontSize: 14,
                        color: GwentColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${l10n.netWaitHint} ${l10n.netWaitQrHint}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: GwentText.alegreya,
                        fontSize: 16,
                        height: 1.35,
                        color: GwentColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: GwentButton(
              label: l10n.netQrShow,
              style: GwentButtonStyle.secondary,
              fontSize: 21,
              onPressed: widget.onShowQr,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: GwentButton(
              label: l10n.dialogCancel,
              style: GwentButtonStyle.secondary,
              fontSize: 21,
              onPressed: widget.onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1;
      canvas.drawCircle(
        center,
        radius * (0.35 + 0.65 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = GwentColors.gold.withValues(alpha: 0.55 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Блок игрока в лобби (макет 9, экраны 4a–4g): герб фракции, имя, роль, фракция и лидер или подсказка, что игрок
/// делает, и состояние связи.
class RoomPlayerCard extends StatelessWidget {
  /// Создаёт блок.
  const RoomPlayerCard({
    super.key,
    required this.name,
    required this.role,
    required this.stage,
    required this.online,
    this.faction,
    this.description,
    this.mine = false,
  });

  /// Имя игрока.
  final String name;

  /// Роль: «Вы · хост», «гость».
  final String role;

  /// Фракция колоды; `null`, пока колода не выбрана.
  final GwentFaction? faction;

  /// «Фракция · лидер»; `null`, пока колода не выбрана.
  final String? description;

  /// Что игрок делает.
  final LobbyStage stage;

  /// Игрок на связи.
  final bool online;

  /// Это блок самого игрока.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = stage == LobbyStage.ready;
    final status = switch (stage) {
      LobbyStage.choosing => l10n.netStageChoosing,
      LobbyStage.building => l10n.netStageBuilding,
      LobbyStage.chosen => l10n.netStageChosen,
      LobbyStage.ready => l10n.netStageReady,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GwentColors.rowSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ready ? GwentColors.brass : GwentColors.panelLine, width: ready ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 12,
          children: [
            FactionMedallion(faction: faction ?? GwentFaction.neutral, size: 52, crestSize: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: GwentText.cormorant,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      height: 1.1,
                      color: GwentColors.textPrimary,
                    ),
                  ),
                  Text(
                    role,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontSize: 13,
                      color: GwentColors.textSecondary,
                    ),
                  ),
                  Text(
                    description ?? l10n.netPlayerPending,
                    style: TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontSize: 14,
                      height: 1.2,
                      color: description == null ? GwentColors.muted : GwentColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 8,
              children: [
                StatusTag(
                  status,
                  background: ready ? GwentColors.goldSurface : GwentColors.surfaceSunken,
                  color: ready ? GwentColors.goldHighlight : GwentColors.textTertiary,
                  ring: ready ? GwentColors.brass : GwentColors.muted,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: online ? GwentColors.goldHighlight : GwentColors.debuff,
                      ),
                      child: const SizedBox.square(dimension: 8),
                    ),
                    Text(
                      online ? l10n.netLinkOk : l10n.netLinkLost,
                      style: const TextStyle(
                        fontFamily: GwentText.alegreya,
                        fontSize: 12,
                        color: GwentColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children, this.bad = false});

  final List<Widget> children;
  final bool bad;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: GwentColors.panel,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: bad ? GwentColors.dangerPanelRing : GwentColors.line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: children),
    ),
  );
}

TextStyle _caption(Color color, {double size = 14}) =>
    TextStyle(fontFamily: GwentText.alegreya, fontSize: size, height: 1.25, color: color);

/// Блок колоды, пока она не выбрана (макет 9, экран 4a).
class RoomNoDeck extends StatelessWidget {
  /// Создаёт блок.
  const RoomNoDeck({super.key, required this.onPick, required this.onBuild});

  /// Выбрать сохранённую колоду.
  final VoidCallback onPick;

  /// Собрать новую колоду.
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Panel(
      children: [
        Text(
          l10n.netMyDeck,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: GwentText.cormorant,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: GwentColors.textPrimary,
          ),
        ),
        Text(l10n.netNoDeck, style: _caption(GwentColors.textTertiary, size: 16)),
        Text(l10n.netNoDeckNote, style: _caption(GwentColors.textSecondary)),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: GwentButton(
                label: l10n.netDeckPick,
                style: GwentButtonStyle.secondary,
                height: 48,
                fontSize: 19,
                onPressed: onPick,
              ),
            ),
            Expanded(
              child: GwentButton(
                label: l10n.netDeckBuild,
                style: GwentButtonStyle.secondary,
                height: 48,
                fontSize: 19,
                onPressed: onBuild,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Блок выбранной колоды (макет 9, экраны 4d и 4e): название, правила со счётчиками и кнопки «Сменить» и «Изменить».
class RoomDeckBlock extends StatelessWidget {
  /// Создаёт блок. [locked] прячет кнопки, пока игрок готов.
  const RoomDeckBlock({
    super.key,
    required this.deck,
    required this.stats,
    required this.rules,
    required this.invalid,
    required this.locked,
    required this.onChange,
    required this.onEdit,
  });

  /// Колода.
  final Deck deck;

  /// Счётчики колоды; `null`, пока правила не загружены.
  final DeckStats? stats;

  /// Правила сборки; `null`, пока не загружены.
  final DeckRules? rules;

  /// Колода нарушает правила.
  final bool invalid;

  /// Игрок готов: колоду менять нельзя.
  final bool locked;

  /// Выбрать другую колоду.
  final VoidCallback onChange;

  /// Изменить колоду в конструкторе.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = this.stats;
    final rules = this.rules;
    Widget rule(String label, String value, {required bool ok}) => Row(
      children: [
        Expanded(child: Text(label, style: _caption(GwentColors.textSecondary))),
        Text(
          value,
          style: _caption(ok ? GwentColors.buff : GwentColors.errorText).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
    return _Panel(
      bad: invalid,
      children: [
        Text(
          deck.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: GwentText.cormorant,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: GwentColors.textPrimary,
          ),
        ),
        if (stats != null && rules != null) ...[
          rule(
            l10n.netRuleUnits(rules.gameRules.minUnitCards),
            '${stats.units}',
            ok: stats.units >= rules.gameRules.minUnitCards,
          ),
          rule(
            l10n.netRuleSpecials(rules.gameRules.maxSpecialCards),
            '${stats.specials}',
            ok: stats.specials <= rules.gameRules.maxSpecialCards,
          ),
          rule(l10n.netRuleLeader, '1 / 1', ok: true),
        ],
        if (!locked)
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: GwentButton(
                  label: l10n.netDeckChange,
                  style: GwentButtonStyle.secondary,
                  height: 48,
                  fontSize: 19,
                  onPressed: onChange,
                ),
              ),
              Expanded(
                child: GwentButton(
                  label: l10n.netDeckEdit,
                  style: GwentButtonStyle.secondary,
                  height: 48,
                  fontSize: 19,
                  onPressed: onEdit,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Отсчёт перед матчем поверх лобби (макет 9, экран 4f): «Оба готовы», цифра 3-2-1 и «Отменить готовность».
class RoomCountdown extends StatelessWidget {
  /// Создаёт отсчёт.
  const RoomCountdown({super.key, required this.left, required this.onCancel});

  /// Сколько секунд осталось.
  final int left;

  /// Игрок отменил готовность.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Positioned.fill(
      child: ColoredBox(
        color: GwentColors.scrimDetail,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      label: '${l10n.netCountdownTitle}. $left',
                      excludeSemantics: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: [
                          Text(
                            l10n.netCountdownTitle,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: GwentText.cormorant,
                              fontWeight: FontWeight.w700,
                              fontSize: 30,
                              color: GwentColors.goldHighlight,
                            ),
                          ),
                          Text(
                            '$left',
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: GwentText.cormorant,
                              fontWeight: FontWeight.w700,
                              fontSize: 120,
                              height: 1.05,
                              color: GwentColors.textPrimary,
                            ),
                          ),
                          Text(l10n.netCountdownStarting, style: _caption(GwentColors.textSecondary, size: 17)),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: GwentButton(
                    label: l10n.netReadyCancel,
                    style: GwentButtonStyle.secondary,
                    solid: true,
                    fontSize: 21,
                    onPressed: onCancel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Запрос хосту: гость постучался в лобби и ждёт ответа. Занимает экран, пока хост не ответит или гость не уйдёт
/// (ADR 0022). Кнопки друг под другом: подписи не переносятся на вторую строку.
class RoomAdmission extends StatelessWidget {
  /// Создаёт запрос про игрока [name].
  const RoomAdmission({super.key, required this.name, required this.onAccept, required this.onDecline});

  /// Имя гостя из его `hello`.
  final String name;

  /// Хост пускает гостя.
  final VoidCallback onAccept;

  /// Хост отказывает гостю.
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = l10n.netAdmitTitle(name.isEmpty ? l10n.netOpponentName : name);
    return Positioned.fill(
      child: ColoredBox(
        color: GwentColors.scrimDetail,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Center(
              child: Semantics(
                liveRegion: true,
                label: title,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 14,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: GwentText.cormorant,
                        fontWeight: FontWeight.w700,
                        fontSize: 30,
                        height: 1.1,
                        color: GwentColors.goldHighlight,
                      ),
                    ),
                    Text(
                      l10n.netAdmitBody,
                      textAlign: TextAlign.center,
                      style: _caption(GwentColors.textSecondary, size: 17),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: GwentButton(label: l10n.netAdmitAccept, fontSize: 21, onPressed: onAccept),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: GwentButton(
                        label: l10n.netAdmitDecline,
                        style: GwentButtonStyle.secondary,
                        solid: true,
                        fontSize: 21,
                        onPressed: onDecline,
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
  }
}
