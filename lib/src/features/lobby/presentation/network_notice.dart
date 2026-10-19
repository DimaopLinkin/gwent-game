import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent_net/gwent_net.dart' show JoinRefusal;

/// Заголовок и пояснение сообщения о сети (макет 9, раздел 7).
typedef NoticeText = ({String title, String text});

/// Что сказать игроку о неудачной попытке создать игру или подключиться к ней.
NoticeText noticeOfResult(AppLocalizations l10n, NetworkOpenResult result) => switch (result) {
  NetworkRefused(:final reason) => noticeOfRefusal(l10n, reason),
  NetworkUnavailable() => (title: l10n.netNoticeUnavailableTitle, text: l10n.netNoticeUnavailableText),
  NetworkUnreachable() => (title: l10n.netNoticeFailTitle, text: l10n.netNoticeFailText),
  NetworkContentUnavailable() => (title: l10n.menuContentFailed, text: ''),
  NetworkGameOpened() => (title: '', text: ''),
};

/// Что сказать игроку об отказе хоста.
NoticeText noticeOfRefusal(AppLocalizations l10n, JoinRefusal reason) => switch (reason) {
  JoinRefusal.protocolMismatch => (title: l10n.netNoticeIncompatibleTitle, text: l10n.netNoticeIncompatibleText),
  JoinRefusal.rulesetMismatch => (title: l10n.netNoticeRulesetTitle, text: l10n.netNoticeRulesetText),
  JoinRefusal.matchFull => (title: l10n.netNoticeFullTitle, text: l10n.netNoticeFullText),
  JoinRefusal.unknownResumeToken => (title: l10n.netNoticeFailTitle, text: l10n.netNoticeFailText),
};

/// Что сказать игроку о том, почему комната закончилась без партии.
NoticeText noticeOfEnd(AppLocalizations l10n, RoomEnd end) => switch (end) {
  RoomRefused(:final reason) => noticeOfRefusal(l10n, reason),
  RoomHostClosed() => (title: l10n.netNoticeClosedTitle, text: l10n.netNoticeClosedText),
  RoomConnectionLost() => (title: l10n.netNoticeLostTitle, text: l10n.netNoticeLostText),
};

/// Кнопка сообщения.
typedef NoticeAction = ({String label, GwentButtonStyle style, VoidCallback onPressed});

/// Сообщение о сети посреди экрана: значок, заголовок, пояснение и кнопки (макет 9, раздел 7).
class NetworkNotice extends StatelessWidget {
  /// Создаёт сообщение.
  const NetworkNotice({super.key, required this.title, required this.text, required this.actions});

  /// Заголовок.
  final String title;

  /// Пояснение; пустое не показывается.
  final String text;

  /// Кнопки сверху вниз; первая главная.
  final List<NoticeAction> actions;

  @override
  Widget build(BuildContext context) => Padding(
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
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GwentColors.errorSurface,
                      border: Border.fromBorderSide(BorderSide(color: GwentColors.dangerPanelRing, width: 1.5)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: GwentIconView(GwentIcon.iconWifi, size: 40, color: GwentColors.errorText),
                    ),
                  ),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: GwentText.cormorant,
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1.1,
                        color: GwentColors.textPrimary,
                      ),
                    ),
                  ),
                  if (text.isNotEmpty)
                    Text(
                      text,
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
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              width: double.infinity,
              child: GwentButton(
                label: action.label,
                style: action.style,
                fontSize: 21,
                onPressed: action.onPressed,
              ),
            ),
          ),
      ],
    ),
  );
}
