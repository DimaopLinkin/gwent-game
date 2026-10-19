import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/leader_name.dart';
import 'package:gwent/src/core/presentation/components/confirm_dialog.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_issue_text.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/lobby/presentation/network_notice.dart';
import 'package:gwent/src/features/lobby/presentation/room_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/room_state.dart';
import 'package:gwent/src/features/lobby/presentation/room_widgets.dart';
import 'package:gwent_engine/gwent_engine.dart' show LeaderId;
import 'package:gwent_net/gwent_net.dart' show LobbyStage;

/// Комната сетевой игры до начала партии (макет 9, экраны 2b и 4a–4g): хост ждёт соперника, затем оба выбирают
/// колоды и отмечают готовность; когда готовы оба, идёт отсчёт 3-2-1 и начинается партия.
///
/// Выбор сохранённой колоды ([onPickDeck]) и конструктор ([onBuildDeck]) открываются отдельными экранами и
/// возвращают идентификатор колоды или `null`.
class RoomScreen extends StatelessWidget {
  /// Создаёт экран.
  const RoomScreen({
    super.key,
    required this.isHost,
    required this.title,
    required this.onPickDeck,
    required this.onBuildDeck,
    required this.onShowQr,
    required this.onStarted,
    required this.onLeft,
  });

  /// Этот телефон создал игру.
  final bool isHost;

  /// Название партии.
  final String title;

  /// Открывает выбор сохранённой колоды; возвращает идентификатор выбранной или `null`.
  final Future<String?> Function(String? currentDeckId) onPickDeck;

  /// Открывает конструктор: новую колоду или колоду [deckId]; возвращает идентификатор сохранённой или `null`.
  final Future<String?> Function(String? deckId) onBuildDeck;

  /// Хост хочет показать QR-код партии.
  final VoidCallback onShowQr;

  /// Хост начал партию.
  final VoidCallback onStarted;

  /// Игрок ушёл из комнаты (или комната закрылась).
  final VoidCallback onLeft;

  Future<void> _confirmLeave(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<RoomCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.netLeaveTitle,
      body: isHost ? l10n.netLeaveBodyHost : l10n.netLeaveBodyGuest,
      confirmLabel: l10n.netLeaveConfirm,
    );
    // Пока диалог был открыт, мог кончиться отсчёт: партия уже идёт, и уходить из неё отсюда нельзя.
    if (!confirmed || cubit.state.room.started) return;
    await cubit.leave();
    onLeft();
  }

  Future<void> _edit(BuildContext context, {required bool build, String? deckId}) async {
    final cubit = context.read<RoomCubit>();
    cubit.startEditing(building: build);
    final picked = await (build ? onBuildDeck(deckId) : onPickDeck(deckId));
    await cubit.finishEditing(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<RoomCubit, RoomState>(
      listenWhen: (previous, current) => !previous.room.started && current.room.started,
      listener: (context, state) => onStarted(),
      builder: (context, state) {
        final room = state.room;
        final end = room.end;
        return PopScope(
          // Посреди комнаты системное «назад» не уходит молча: оно спрашивает, как и стрелка в шапке.
          canPop: end != null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_confirmLeave(context));
          },
          child: ScreenBackdrop(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  children: [
                    ScreenHeader(
                      title: room.opponent == null && !room.started ? l10n.netCreateTitle : l10n.netRoomTitle,
                      subtitle: room.opponent == null
                          ? null
                          : l10n.netRoomSubtitle(isHost ? title : _hostName(room, l10n)),
                      titleSize: 32,
                      onBack: end != null ? onLeft : () => unawaited(_confirmLeave(context)),
                    ),
                    Expanded(
                      child: switch (end) {
                        final end? => _Ended(end: end, onBack: onLeft),
                        null when room.started => const GameLoader(),
                        null when room.opponent == null =>
                          isHost
                              ? RoomWaiting(
                                  title: title,
                                  onShowQr: onShowQr,
                                  onCancel: () => unawaited(_confirmLeave(context)),
                                )
                              : const GameLoader(caption: ''),
                        null => _Lobby(
                          state: state,
                          isHost: isHost,
                          onPick: () => unawaited(_edit(context, build: false, deckId: state.deck?.id)),
                          onBuild: () => unawaited(_edit(context, build: true)),
                          onEdit: () => unawaited(_edit(context, build: true, deckId: state.deck?.id)),
                          onReady: context.read<RoomCubit>().ready,
                          onCancelReady: context.read<RoomCubit>().cancelReady,
                        ),
                      },
                    ),
                  ],
                ),
                if (state.countdownLeft case final left? when end == null && !room.started)
                  RoomCountdown(left: left, onCancel: context.read<RoomCubit>().cancelReady),
              ],
            ),
          ),
        );
      },
    );
  }

  String _hostName(LobbyRoom room, AppLocalizations l10n) {
    final name = room.opponent?.name ?? '';
    return name.isEmpty ? l10n.netOpponentName : name;
  }
}

class _Ended extends StatelessWidget {
  const _Ended({required this.end, required this.onBack});

  final RoomEnd end;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notice = noticeOfEnd(l10n, end);
    return NetworkNotice(
      title: notice.title,
      text: notice.text,
      actions: [(label: l10n.netNoticeBack, style: GwentButtonStyle.primary, onPressed: onBack)],
    );
  }
}

/// Фракция, название фракции и короткое имя лидера по UUID лидера.
({GwentFaction faction, String factionName, String leaderName})? _describe(DeckRules? rules, LeaderId? leader) {
  if (rules == null || leader == null) return null;
  for (final info in rules.factionInfos) {
    final found = info.leader(leader.value);
    if (found != null) {
      return (
        faction: GwentFaction.fromKey(info.key),
        factionName: info.name,
        leaderName: splitLeaderName(found.name).$1,
      );
    }
  }
  return null;
}

class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.state,
    required this.isHost,
    required this.onPick,
    required this.onBuild,
    required this.onEdit,
    required this.onReady,
    required this.onCancelReady,
  });

  final RoomState state;
  final bool isHost;
  final VoidCallback onPick;
  final VoidCallback onBuild;
  final VoidCallback onEdit;
  final VoidCallback onReady;
  final VoidCallback onCancelReady;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final room = state.room;
    final opponent = room.opponent!;
    final rules = state.rules;
    final deck = state.deck;
    final ready = room.myStage == LobbyStage.ready;
    final theirs = _describe(rules, opponent.leader);
    final mine = _describe(rules, room.myLeader);
    final online = room.link == RoomLink.online;
    final hint = room.deckRefused
        ? l10n.netDeckRefused
        : deck == null
        ? l10n.netPickDeckHint
        : rules == null
        ? null
        : DeckIssueText(pack: rules.pack, l10n: l10n).firstOf(state.issues);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          RoomPlayerCard(
            name: opponent.name.isEmpty ? l10n.netOpponentName : opponent.name,
            role: isHost ? l10n.netRoleGuest : l10n.netRoleHost,
            faction: theirs?.faction,
            description: theirs == null ? null : l10n.netFactionLeader(theirs.factionName, theirs.leaderName),
            stage: opponent.stage,
            online: opponent.online,
          ),
          RoomPlayerCard(
            name: context.read<RoomCubit>().game.playerName,
            role: isHost ? l10n.netRoleYouHost : l10n.netRoleYouGuest,
            faction: mine?.faction,
            description: mine == null ? null : l10n.netFactionLeader(mine.factionName, mine.leaderName),
            stage: room.myStage,
            online: online,
            mine: true,
          ),
          if (deck == null)
            RoomNoDeck(onPick: onPick, onBuild: onBuild)
          else
            RoomDeckBlock(
              deck: deck,
              stats: rules?.statsOf(DeckDraft.of(deck)),
              rules: rules,
              invalid: state.issues.isNotEmpty,
              locked: ready,
              onChange: onPick,
              onEdit: onEdit,
            ),
          const Spacer(),
          if (hint != null && !ready)
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GwentText.alegreya,
                fontSize: 15,
                color: deck == null ? GwentColors.textSecondary : GwentColors.errorText,
              ),
            ),
          if (ready)
            GwentButton(label: l10n.netReadyCancel, style: GwentButtonStyle.secondary, onPressed: onCancelReady)
          else
            GwentButton(label: l10n.netReady, onPressed: state.deckValid && online ? onReady : null),
        ],
      ),
    );
  }
}
