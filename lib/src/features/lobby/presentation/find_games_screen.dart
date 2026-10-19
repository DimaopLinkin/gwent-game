import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/components/status_tag.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/lobby/application/discover_network_games.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/network_access.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_state.dart';
import 'package:gwent/src/features/lobby/presentation/network_notice.dart';
import 'package:gwent_net/gwent_net.dart' show JoinRefusal;

/// Поиск партий рядом (макет 9, экраны 3a и 3b): список обновляется сам, партию с другой версией видно, но войти
/// в неё нельзя.
///
/// Когда гость подключился, экран сообщает [onJoined]: комнату показывает отдельный экран.
class FindGamesScreen extends StatelessWidget {
  /// Создаёт экран.
  const FindGamesScreen({super.key, required this.onJoined, required this.onScan, required this.onBack});

  /// Гость подключился к партии.
  final VoidCallback onJoined;

  /// Открывает сканер QR-кода; возвращает адрес партии или `null`, если игрок вернулся без кода.
  final Future<GameAddress?> Function() onScan;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  Future<void> _scan(FindGamesCubit cubit) async {
    final address = await onScan();
    if (address != null) await cubit.joinByCode(address);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<FindGamesCubit>();
    void scan() => unawaited(_scan(cubit));
    return ScreenBackdrop(
      child: BlocConsumer<FindGamesCubit, FindGamesState>(
        listenWhen: (previous, current) => current is FindGamesJoined,
        listener: (context, state) => onJoined(),
        builder: (context, state) => Column(
          children: [
            ScreenHeader(title: l10n.netFindTitle, titleSize: 32, onBack: onBack),
            Expanded(
              child: switch (state) {
                FindGamesSearching(:final games) => _Games(
                  games: games,
                  joiningId: null,
                  onJoin: cubit.join,
                  onScan: scan,
                ),
                FindGamesJoining(:final games, :final gameId) => _Games(
                  games: games,
                  joiningId: gameId,
                  onJoin: null,
                  onScan: null,
                ),
                FindGamesJoiningByCode() || FindGamesJoined() => const GameLoader(),
                FindGamesUnavailable(:final problem) => _Notice(
                  result: NetworkUnavailable(problem: problem),
                  onRetry: cubit.search,
                  onFix: switch (problem) {
                    null => null,
                    NetworkProblem.localNetworkExplainer => () => unawaited(cubit.continueAfterExplainer()),
                    final fixable => () => unawaited(cubit.openSettings(fixable)),
                  },
                  onScan: null,
                  onBack: onBack,
                ),
                FindGamesFailed(:final result) => _Notice(
                  result: result,
                  onRetry: () => unawaited(cubit.retry()),
                  onFix: null,
                  onScan: scan,
                  onBack: cubit.search,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.result,
    required this.onRetry,
    required this.onFix,
    required this.onScan,
    required this.onBack,
  });

  final NetworkOpenResult result;
  final VoidCallback onRetry;

  /// Главное действие сообщения о причине сбоя сети: настройки или переход к системному запросу.
  final VoidCallback? onFix;

  /// Открывает сканер QR-кода; `null`, если QR здесь не поможет.
  final VoidCallback? onScan;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notice = noticeOfResult(l10n, result);
    if (result case NetworkUnavailable(:final problem?) when onFix != null) {
      return NetworkNotice(
        title: notice.title,
        text: notice.text,
        icon: noticeIcon(problem),
        steps: noticeSteps(l10n, problem),
        danger: problem == NetworkProblem.localNetworkDenied,
        actions: noticeActions(l10n, problem, onFix: onFix!, onBack: onBack),
      );
    }
    // Несовместимой версией «Повторить» не помочь.
    final retryable = switch (result) {
      NetworkRefused(:final reason) => reason == JoinRefusal.matchFull || reason == JoinRefusal.unknownResumeToken,
      _ => true,
    };
    return NetworkNotice(
      title: notice.title,
      text: notice.text,
      actions: [
        if (retryable) (label: l10n.netNoticeRetry, style: GwentButtonStyle.primary, onPressed: onRetry),
        if (retryable && onScan != null)
          (label: l10n.netScanButton, style: GwentButtonStyle.secondary, onPressed: onScan!),
        (
          label: l10n.netNoticeBack,
          style: retryable ? GwentButtonStyle.secondary : GwentButtonStyle.primary,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _Games extends StatelessWidget {
  const _Games({required this.games, required this.joiningId, required this.onJoin, required this.onScan});

  final List<DiscoveredGame> games;
  final String? joiningId;
  final ValueChanged<DiscoveredGame>? onJoin;

  /// Открывает сканер QR-кода; `null`, пока идёт подключение.
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 8,
            children: [
              const GwentSpinner(size: 16),
              Expanded(
                child: Text(
                  l10n.netFindSearching,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                    color: GwentColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: games.isEmpty
                ? const _Empty()
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final game in games)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _GameRow(
                            game: game,
                            joining: joiningId == game.found.ad.id,
                            onJoin: onJoin == null ? null : () => onJoin!(game),
                          ),
                        ),
                    ],
                  ),
          ),
          GwentButton(
            label: l10n.netScanButton,
            style: GwentButtonStyle.secondary,
            fontSize: 21,
            onPressed: onScan,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          const GwentIconView(GwentIcon.iconWifi, size: 48, color: GwentColors.muted),
          Text(
            l10n.netFindEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: GwentText.cormorant,
              fontWeight: FontWeight.w700,
              fontSize: 24,
              color: GwentColors.textPrimary,
            ),
          ),
          Text(
            l10n.netFindEmptyNote,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: GwentText.alegreya, fontSize: 15, color: GwentColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.joining, required this.onJoin});

  final DiscoveredGame game;
  final bool joining;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final joinable = game.joinable;
    final status = switch (game.refusal) {
      null => l10n.netFindVersionOk,
      JoinRefusal.protocolMismatch => l10n.netFindProtocolMismatch,
      JoinRefusal.rulesetMismatch => l10n.netFindRulesetMismatch,
      JoinRefusal.matchFull || JoinRefusal.unknownResumeToken => l10n.netFindFull,
    };
    final name = game.found.ad.hostName;
    final enabled = joinable && onJoin != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.netFindGameSemantics(name, status),
      onTap: enabled ? onJoin : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onJoin : null,
        child: Opacity(
          opacity: joinable ? 1 : 0.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: GwentColors.rowSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: joinable ? GwentColors.brass : GwentColors.panelLine),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: GwentText.cormorant,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            height: 1.1,
                            color: GwentColors.textPrimary,
                          ),
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            fontFamily: GwentText.alegreya,
                            fontSize: 14,
                            color: joinable ? GwentColors.buff : GwentColors.errorText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (joining)
                    const GwentSpinner(size: 20)
                  else if (joinable)
                    StatusTag(
                      l10n.netFindJoin,
                      background: GwentColors.goldSurface,
                      color: GwentColors.goldHighlight,
                      ring: GwentColors.brass,
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
