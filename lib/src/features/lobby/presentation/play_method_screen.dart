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

/// Выбор способа соединения для игры на двух телефонах (макет 9, экран 1a): Wi-Fi доступен, Bluetooth «скоро».
///
/// Кнопки внизу ведут на экраны хоста и гостя.
class PlayMethodScreen extends StatelessWidget {
  /// Создаёт экран.
  const PlayMethodScreen({super.key, required this.onCreate, required this.onFind, required this.onBack});

  /// Игрок хочет создать партию.
  final VoidCallback onCreate;

  /// Игрок хочет найти партию рядом.
  final VoidCallback onFind;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: Column(
        children: [
          ScreenHeader(title: l10n.netPlayTitle, titleSize: 32, onBack: onBack),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
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
                  ),
                  _MethodCard(
                    icon: GwentIcon.iconBluetooth,
                    title: l10n.netMethodBluetooth,
                    note: l10n.netMethodBluetoothNote,
                    available: false,
                    soon: l10n.netMethodSoon,
                  ),
                  const Spacer(),
                  GwentButton(label: l10n.netCreateGame, onPressed: onCreate),
                  GwentButton(label: l10n.netFindGame, style: GwentButtonStyle.secondary, onPressed: onFind),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.icon, required this.title, required this.note, required this.available, this.soon});

  final GwentIcon icon;
  final String title;
  final String note;
  final bool available;
  final String? soon;

  @override
  Widget build(BuildContext context) {
    final soon = this.soon;
    return Opacity(
      opacity: available ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: GwentColors.rowSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: available ? GwentColors.brass : GwentColors.panelLine, width: available ? 1.5 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            spacing: 14,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: available ? GwentColors.brassHighlight : GwentColors.surfaceSunken,
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
                StatusTag(soon, background: GwentColors.surfaceSunken, color: GwentColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
