import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_state.dart';
import 'package:gwent/src/features/lobby/presentation/create_online_game_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/network_notice.dart';

/// Создание комнаты для игры через интернет: пока комната создаётся на сервере, экран показывает загрузку, а при
/// неудаче объясняет причину (сервис недоступен, слишком много комнат) и предлагает повторить.
///
/// Когда комната создана, экран сообщает [onCreated]: код и ожидание соперника показывает комната лобби.
class CreateOnlineGameScreen extends StatelessWidget {
  /// Создаёт экран.
  const CreateOnlineGameScreen({super.key, required this.onCreated, required this.onBack});

  /// Комната создана на сервере.
  final VoidCallback onCreated;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: BlocConsumer<CreateOnlineGameCubit, CreateGameState>(
        listenWhen: (previous, current) => current is CreateGameCreated,
        listener: (context, state) => onCreated(),
        builder: (context, state) => Column(
          children: [
            ScreenHeader(title: l10n.netOnlineCreateTitle, titleSize: 32, onBack: onBack),
            Expanded(
              child: switch (state) {
                CreateGameFailed(:final result) => _Failed(result: result, onBack: onBack),
                _ => GameLoader(caption: l10n.netOnlineCreating),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.result, required this.onBack});

  final NetworkOpenResult result;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notice = noticeOfResult(l10n, result, link: NoticeLink.onlineHost);
    return NetworkNotice(
      title: notice.title,
      text: notice.text,
      icon: GwentIcon.iconGlobe,
      actions: [
        (
          label: l10n.netNoticeRetry,
          style: GwentButtonStyle.primary,
          onPressed: () => unawaited(context.read<CreateOnlineGameCubit>().create()),
        ),
        (label: l10n.netNoticeBack, style: GwentButtonStyle.secondary, onPressed: onBack),
      ],
    );
  }
}
