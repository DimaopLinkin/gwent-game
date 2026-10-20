import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/lobby/domain/network_access.dart';
import 'package:gwent_net/gwent_net.dart' show JoinRefusal;

/// Заголовок и пояснение сообщения о сети (макет 9, раздел 7).
typedef NoticeText = ({String title, String text});

/// Как связаны телефоны: от этого зависят слова в сообщениях о сети. Через интернет нет ни Wi-Fi, ни поиска рядом,
/// зато есть сервис комнат, который может не отвечать, и код комнаты.
enum NoticeLink {
  /// Wi-Fi: одна сеть, поиск рядом.
  wifi,

  /// Через интернет, этот телефон создал комнату.
  onlineHost,

  /// Через интернет, этот телефон вошёл в комнату по коду.
  onlineGuest,
}

/// Что сказать игроку о неудачной попытке создать игру или подключиться к ней.
NoticeText noticeOfResult(AppLocalizations l10n, NetworkOpenResult result, {NoticeLink link = NoticeLink.wifi}) =>
    switch (result) {
      NetworkRefused(:final reason) => noticeOfRefusal(l10n, reason),
      NetworkUnavailable(:final problem?) => noticeOfProblem(l10n, problem),
      NetworkUnavailable() when link != NoticeLink.wifi => (
        title: l10n.netNoticeServiceTitle,
        text: l10n.netNoticeServiceText,
      ),
      NetworkUnavailable() => (title: l10n.netNoticeUnavailableTitle, text: l10n.netNoticeUnavailableText),
      NetworkUnreachable() when link != NoticeLink.wifi => (
        title: l10n.netNoticeFailTitle,
        text: l10n.netNoticeOnlineFailText,
      ),
      NetworkUnreachable() => (title: l10n.netNoticeFailTitle, text: l10n.netNoticeFailText),
      NetworkRoomRefused(:final failure) => noticeOfRoomFailure(l10n, failure),
      NetworkContentUnavailable() => (title: l10n.menuContentFailed, text: ''),
      NetworkGameOpened() => (title: '', text: ''),
    };

/// Что сказать игроку об отказе комнаты в игре через интернет. Остальные причины ([LobbyFailure.unavailable],
/// [LobbyFailure.unreachable]) в такие итоги не попадают, но получают общий текст о неудачном подключении.
NoticeText noticeOfRoomFailure(AppLocalizations l10n, LobbyFailure failure) => switch (failure) {
  LobbyFailure.codeNotFound => (title: l10n.netNoticeCodeNotFoundTitle, text: l10n.netNoticeCodeNotFoundText),
  LobbyFailure.roomFull => (title: l10n.netNoticeRoomFullTitle, text: l10n.netNoticeRoomFullText),
  LobbyFailure.roomClosed => (title: l10n.netNoticeRoomClosedTitle, text: l10n.netNoticeRoomClosedText),
  LobbyFailure.ownRoom => (title: l10n.netNoticeOwnRoomTitle, text: l10n.netNoticeOwnRoomText),
  LobbyFailure.tooManyAttempts => (
    title: l10n.netNoticeTooManyAttemptsTitle,
    text: l10n.netNoticeTooManyAttemptsText,
  ),
  LobbyFailure.tooManyRooms => (title: l10n.netNoticeTooManyRoomsTitle, text: l10n.netNoticeTooManyRoomsText),
  LobbyFailure.unavailable || LobbyFailure.unreachable => (
    title: l10n.netNoticeFailTitle,
    text: l10n.netNoticeFailText,
  ),
};

/// Что сказать игроку о причине, из-за которой сеть не работает (макет 9, экраны 7c–7e).
NoticeText noticeOfProblem(AppLocalizations l10n, NetworkProblem problem) => switch (problem) {
  NetworkProblem.wifiOff => (title: l10n.netProblemWifiTitle, text: l10n.netProblemWifiText),
  NetworkProblem.localNetworkExplainer => (title: l10n.netProblemExplainTitle, text: l10n.netProblemExplainText),
  NetworkProblem.localNetworkDenied => (title: l10n.netProblemDeniedTitle, text: l10n.netProblemDeniedText),
};

/// Шаги инструкции под пояснением о [problem]; у остальных причин шагов нет.
List<String> noticeSteps(AppLocalizations l10n, NetworkProblem problem) => switch (problem) {
  NetworkProblem.wifiOff => const [],
  NetworkProblem.localNetworkExplainer => [
    l10n.netProblemExplainStep1,
    l10n.netProblemExplainStep2,
    l10n.netProblemExplainStep3,
  ],
  NetworkProblem.localNetworkDenied => [
    l10n.netProblemDeniedStep1,
    l10n.netProblemDeniedStep2,
    l10n.netProblemDeniedStep3,
  ],
};

/// Значок сообщения о [problem].
GwentIcon noticeIcon(NetworkProblem? problem) => switch (problem) {
  NetworkProblem.wifiOff => GwentIcon.iconWifiOff,
  NetworkProblem.localNetworkExplainer => GwentIcon.iconLocalNetwork,
  NetworkProblem.localNetworkDenied => GwentIcon.iconLock,
  null => GwentIcon.iconWifi,
};

/// Кнопки сообщения о [problem]: что сделать и как уйти. [onFix] — главное действие.
List<NoticeAction> noticeActions(
  AppLocalizations l10n,
  NetworkProblem problem, {
  required VoidCallback onFix,
  required VoidCallback onBack,
}) => switch (problem) {
  NetworkProblem.wifiOff || NetworkProblem.localNetworkDenied => [
    (label: l10n.netProblemSettings, style: GwentButtonStyle.primary, onPressed: onFix),
    (label: l10n.netNoticeBack, style: GwentButtonStyle.secondary, onPressed: onBack),
  ],
  NetworkProblem.localNetworkExplainer => [
    (label: l10n.netProblemContinue, style: GwentButtonStyle.primary, onPressed: onFix),
    (label: l10n.netProblemLater, style: GwentButtonStyle.secondary, onPressed: onBack),
  ],
};

/// Что сказать игроку об отказе хоста.
NoticeText noticeOfRefusal(AppLocalizations l10n, JoinRefusal reason) => switch (reason) {
  JoinRefusal.protocolMismatch => (title: l10n.netNoticeIncompatibleTitle, text: l10n.netNoticeIncompatibleText),
  JoinRefusal.rulesetMismatch => (title: l10n.netNoticeRulesetTitle, text: l10n.netNoticeRulesetText),
  JoinRefusal.matchFull => (title: l10n.netNoticeFullTitle, text: l10n.netNoticeFullText),
  JoinRefusal.unknownResumeToken => (title: l10n.netNoticeFailTitle, text: l10n.netNoticeFailText),
  JoinRefusal.declined => (title: l10n.netNoticeDeclinedTitle, text: l10n.netNoticeDeclinedText),
};

/// Что сказать игроку о том, почему комната закончилась без партии.
NoticeText noticeOfEnd(AppLocalizations l10n, RoomEnd end, {NoticeLink link = NoticeLink.wifi}) => switch (end) {
  RoomRefused(:final reason) => noticeOfRefusal(l10n, reason),
  RoomHostClosed() => (
    title: l10n.netNoticeClosedTitle,
    text: link == NoticeLink.wifi ? l10n.netNoticeClosedText : l10n.netNoticeOnlineClosedText,
  ),
  RoomConnectionLost() => (
    title: l10n.netNoticeLostTitle,
    text: switch (link) {
      NoticeLink.wifi => l10n.netNoticeLostText,
      NoticeLink.onlineHost => l10n.netNoticeOnlineHostLostText,
      NoticeLink.onlineGuest => l10n.netNoticeOnlineGuestLostText,
    },
  ),
  RoomHostInvalid() => (title: l10n.netNoticeInvalidTitle, text: l10n.netNoticeInvalidText),
};

/// Кнопка сообщения.
typedef NoticeAction = ({String label, GwentButtonStyle style, VoidCallback onPressed});

/// Сообщение о сети посреди экрана: значок, заголовок, пояснение и кнопки (макет 9, раздел 7).
class NetworkNotice extends StatelessWidget {
  /// Создаёт сообщение.
  const NetworkNotice({
    super.key,
    required this.title,
    required this.text,
    required this.actions,
    this.icon = GwentIcon.iconWifi,
    this.steps = const [],
    this.danger = true,
  });

  /// Значок в круге над заголовком.
  final GwentIcon icon;

  /// Нумерованные шаги на пергаменте под пояснением; пустой список их не показывает.
  final List<String> steps;

  /// Тревожный тон (красный) или спокойный (золотой): золотой у пояснений, красный у отказов.
  final bool danger;

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
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: danger ? GwentColors.errorSurface : GwentColors.goldSurface,
                      border: Border.fromBorderSide(
                        BorderSide(color: danger ? GwentColors.dangerPanelRing : GwentColors.brass, width: 1.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: GwentIconView(
                        icon,
                        size: 40,
                        color: danger ? GwentColors.errorText : GwentColors.goldHighlight,
                      ),
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
                  if (steps.isNotEmpty) _Steps(steps: steps),
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

/// Нумерованная инструкция на пергаменте (макет 9, экраны 7d и 7e).
class _Steps extends StatelessWidget {
  const _Steps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: GwentColors.parchment,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: GwentColors.brass),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          for (final (index, step) in steps.indexed)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              spacing: 10,
              children: [
                Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: GwentColors.onParchmentSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      height: 1.35,
                      color: GwentColors.onParchment,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
