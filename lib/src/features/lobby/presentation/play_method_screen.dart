import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/components/status_tag.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Способ соединения двух телефонов, который игрок выбирает на экране «Играть вдвоём».
enum PlayMethod {
  /// Одна Wi-Fi сеть: партию ищут рядом.
  wifi,

  /// Через интернет: комната с кодом.
  internet,
}

/// Выбор способа соединения для игры на двух телефонах (макет 9, экран 1a): Wi-Fi и интернет доступны, Bluetooth
/// «скоро».
///
/// Кнопки внизу зависят от выбранного способа: в Wi-Fi создают партию и ищут её рядом, через интернет создают комнату
/// и вводят её код.
class PlayMethodScreen extends StatefulWidget {
  /// Создаёт экран. [initial] — способ, выбранный при открытии.
  const PlayMethodScreen({
    super.key,
    required this.onCreate,
    required this.onFind,
    required this.onBack,
    this.initial = PlayMethod.wifi,
  });

  /// Игрок хочет создать партию выбранным способом.
  final ValueChanged<PlayMethod> onCreate;

  /// Игрок хочет найти партию: рядом (Wi-Fi) или по коду (интернет).
  final ValueChanged<PlayMethod> onFind;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  /// Способ, выбранный при открытии.
  final PlayMethod initial;

  @override
  State<PlayMethodScreen> createState() => _PlayMethodScreenState();
}

class _PlayMethodScreenState extends State<PlayMethodScreen> {
  late PlayMethod _method = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final online = _method == PlayMethod.internet;
    return ScreenBackdrop(
      child: Column(
        children: [
          ScreenHeader(title: l10n.netPlayTitle, titleSize: 32, onBack: widget.onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  Text(
                    l10n.netPlayIntro,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontSize: 16,
                      height: 1.35,
                      color: GwentColors.textSecondary,
                    ),
                  ),
                  _MethodCard(
                    icon: GwentIcon.iconWifi,
                    title: l10n.netMethodWifi,
                    note: l10n.netMethodWifiNote,
                    available: true,
                    selected: _method == PlayMethod.wifi,
                    onTap: () => setState(() => _method = PlayMethod.wifi),
                  ),
                  _MethodCard(
                    icon: GwentIcon.iconGlobe,
                    title: l10n.netMethodInternet,
                    note: l10n.netMethodInternetNote,
                    available: true,
                    selected: online,
                    onTap: () => setState(() => _method = PlayMethod.internet),
                  ),
                  _MethodCard(
                    icon: GwentIcon.iconBluetooth,
                    title: l10n.netMethodBluetooth,
                    note: l10n.netMethodBluetoothNote,
                    available: false,
                    soon: l10n.netMethodSoon,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                GwentButton(
                  label: online ? l10n.netCreateRoom : l10n.netCreateGame,
                  onPressed: () => widget.onCreate(_method),
                ),
                GwentButton(
                  label: online ? l10n.netEnterCode : l10n.netFindGame,
                  style: GwentButtonStyle.secondary,
                  onPressed: () => widget.onFind(_method),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.note,
    required this.available,
    this.selected = false,
    this.onTap,
    this.soon,
  });

  final GwentIcon icon;
  final String title;
  final String note;
  final bool available;

  /// Способ выбран: золотая рамка. Недоступный способ не выбирается.
  final bool selected;
  final VoidCallback? onTap;
  final String? soon;

  @override
  Widget build(BuildContext context) {
    final soon = this.soon;
    final card = Opacity(
      opacity: available ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: GwentColors.rowSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? GwentColors.goldHighlight : (available ? GwentColors.brass : GwentColors.panelLine),
            width: selected ? 2 : (available ? 1.5 : 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            spacing: 14,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? GwentColors.goldHighlight
                      : (available ? GwentColors.brassHighlight : GwentColors.surfaceSunken),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: GwentIconView(icon, size: 26, color: available ? GwentColors.onGold : GwentColors.muted),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      title,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: GwentText.cormorant,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        height: 1.1,
                        color: available ? GwentColors.textPrimary : GwentColors.textSecondary,
                      ),
                    ),
                    Text(
                      note,
                      style: const TextStyle(
                        fontFamily: GwentText.alegreya,
                        fontSize: 14,
                        height: 1.25,
                        color: GwentColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (soon != null)
                StatusTag(soon, background: GwentColors.surfaceSunken, color: GwentColors.textSecondary)
              else
                _Radio(selected: selected),
            ],
          ),
        ),
      ),
    );
    if (!available) return card;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $note',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card),
    );
  }
}

/// Кружок выбора справа в карточке способа: заполнен у выбранного.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: selected ? GwentColors.goldHighlight : GwentColors.muted, width: 1.5),
    ),
    child: SizedBox.square(
      dimension: 20,
      child: selected
          ? const Padding(
              padding: EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: GwentColors.goldHighlight),
              ),
            )
          : null,
    ),
  );
}
