import 'package:flutter/material.dart' hide Intent;
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/application/start_match.dart' show LocalMatchRequest;
import 'package:gwent/src/features/match/domain/match_session.dart' show LocalMatchMode;
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Row;

// Экраны партии вокруг поля: выбор режима и колод, передача телефона, пересдача, выбор первого игрока, итог.
// Это простые экраны на токенах темы, без макетов: макеты промптов 4 и 5 (старт партии, итоги) ещё в работе.

/// Действие под сообщением: подпись и нажатие.
typedef MatchAction = ({String label, VoidCallback onPressed, bool primary});

/// Сообщение по центру экрана: заголовок, пояснение, строки и кнопки.
class MatchPanel extends StatelessWidget {
  /// Создаёт панель.
  const MatchPanel({super.key, required this.title, this.body, this.lines = const [], this.actions = const []});

  /// Заголовок.
  final String title;

  /// Пояснение.
  final String? body;

  /// Строки под пояснением, например счёт раундов.
  final List<String> lines;

  /// Кнопки по порядку.
  final List<MatchAction> actions;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Text(title, textAlign: TextAlign.center, style: GwentText.display.copyWith(fontSize: 30)),
            if (body != null) Text(body!, textAlign: TextAlign.center, style: GwentText.body),
            for (final line in lines) Text(line, textAlign: TextAlign.center, style: GwentText.caption),
            for (final action in actions)
              action.primary
                  ? FilledButton(onPressed: action.onPressed, child: Text(action.label))
                  : OutlinedButton(onPressed: action.onPressed, child: Text(action.label)),
          ],
        ),
      ),
    ),
  );
}

/// Выбор режима и колод перед партией.
class MatchSetupStage extends StatelessWidget {
  /// Создаёт экран; [onStart] получает готовый запрос.
  const MatchSetupStage({
    super.key,
    required this.state,
    required this.cubit,
    required this.onStart,
    required this.onExit,
  });

  /// Состояние выбора.
  final MatchSetupState state;

  /// Держатель выбора.
  final MatchSetupCubit cubit;

  /// Игрок начал партию.
  final ValueChanged<LocalMatchRequest> onStart;

  /// Игрок вернулся в меню.
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (state) {
      MatchSetupLoading() => const Center(child: CircularProgressIndicator()),
      MatchSetupFailed() => MatchPanel(
        title: l10n.matchSetupLoadFailed,
        actions: [(label: l10n.matchExit, onPressed: onExit, primary: true)],
      ),
      final MatchSetupReady ready => _ready(context, ready),
    };
  }

  Widget _ready(BuildContext context, MatchSetupReady ready) {
    final l10n = context.l10n;
    final request = ready.request;
    final hotSeat = ready.mode == LocalMatchMode.hotSeat;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.matchSetupTitle, style: GwentText.display.copyWith(fontSize: 30)),
        const SizedBox(height: 16),
        SegmentedButton<LocalMatchMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: LocalMatchMode.vsBot, label: Text(l10n.matchSetupModeBot)),
            ButtonSegment(value: LocalMatchMode.hotSeat, label: Text(l10n.matchSetupModeHotSeat)),
          ],
          selected: {ready.mode},
          onSelectionChanged: (selection) => cubit.selectMode(selection.first),
        ),
        const SizedBox(height: 20),
        _DeckPicker(
          label: l10n.matchSetupDeckOne,
          ready: ready,
          seat: Seat.one,
          onSelected: (id) => cubit.selectDeck(Seat.one, id),
        ),
        const SizedBox(height: 12),
        _DeckPicker(
          label: hotSeat ? l10n.matchSetupDeckTwo : l10n.matchSetupDeckBot,
          ready: ready,
          seat: Seat.two,
          onSelected: (id) => cubit.selectDeck(Seat.two, id),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: request == null ? null : () => onStart(request),
          child: Text(l10n.matchSetupStart),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onExit, child: Text(l10n.matchExit)),
      ],
    );
  }
}

class _DeckPicker extends StatelessWidget {
  const _DeckPicker({required this.label, required this.ready, required this.seat, required this.onSelected});

  final String label;
  final MatchSetupReady ready;
  final Seat seat;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      Text(label, style: GwentText.label),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final deck in ready.decks)
            ChoiceChip(
              label: Text(deck.name),
              selected: ready.deck(seat) == deck.id,
              onSelected: (_) => onSelected(deck.id),
            ),
        ],
      ),
    ],
  );
}

/// Пересдача перед первым раундом: нажатие на карту меняет её, «Готово» завершает.
class MatchRedrawStage extends StatelessWidget {
  /// Создаёт экран пересдачи по проекции [view].
  const MatchRedrawStage({super.key, required this.view, required this.content, required this.onIntent});

  /// Проекция партии.
  final PlayerView view;

  /// Контент партии.
  final GameContent content;

  /// Действие игрока.
  final ValueChanged<Intent> onIntent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final me = view.me;
    if (me.redrawDone) return MatchPanel(title: l10n.matchRedrawTitle, body: l10n.matchRedrawWaiting);
    final left = me.redrawsLeft ?? 0;
    final fieldContent = FieldContent(content: content, l10n: l10n);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            spacing: 6,
            children: [
              Text(l10n.matchRedrawTitle, style: GwentText.display.copyWith(fontSize: 30)),
              Text(l10n.matchRedrawSubtitle(left), textAlign: TextAlign.center, style: GwentText.body),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final card in me.hand ?? const <CardInstance>[])
                  GwentCard(
                    face: fieldContent.face(card),
                    size: CardSize.hand,
                    highlight: left > 0 ? CardHighlight.normal : CardHighlight.disabled,
                    onTap: left > 0 ? () => onIntent(RedrawCard(card.id)) : null,
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () => onIntent(const FinishRedraw()), child: Text(l10n.matchRedrawDone)),
          ),
        ),
      ],
    );
  }
}

/// Выбор первого игрока: Скоя'таэли решают, кто ходит первым.
class MatchFirstPlayerStage extends StatelessWidget {
  /// Создаёт экран выбора по проекции [view].
  const MatchFirstPlayerStage({super.key, required this.view, required this.onIntent});

  /// Проекция партии.
  final PlayerView view;

  /// Действие игрока.
  final ValueChanged<Intent> onIntent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final choice = view.choice;
    if (choice == null) return MatchPanel(title: l10n.matchFirstPlayerTitle, body: l10n.matchFirstPlayerWaiting);
    return MatchPanel(
      title: l10n.matchFirstPlayerTitle,
      actions: [
        for (final option in choice.options)
          if (option is SeatOption)
            (
              label: option.seat == view.viewer ? l10n.matchFirstPlayerMe : l10n.matchFirstPlayerOpponent,
              onPressed: () => onIntent(ChooseOption(option)),
              primary: option.seat == view.viewer,
            ),
      ],
    );
  }
}

/// Итог партии: кто победил, счёт раундов и выход.
class MatchFinishedStage extends StatelessWidget {
  /// Создаёт экран итога по проекции [view].
  const MatchFinishedStage({super.key, required this.view, required this.onExit});

  /// Итоговая проекция.
  final PlayerView view;

  /// Выход из партии.
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final winner = view.outcome?.winner;
    return MatchPanel(
      title: winner == null
          ? l10n.matchFinishedDraw
          : winner == view.viewer
          ? l10n.matchFinishedWin
          : l10n.matchFinishedLose,
      lines: [
        for (final result in view.history)
          l10n.matchFinishedRound(
            result.round,
            result.scores[view.viewer] ?? 0,
            result.scores[view.viewer.opponent] ?? 0,
          ),
      ],
      actions: [(label: l10n.matchExit, onPressed: onExit, primary: true)],
    );
  }
}
