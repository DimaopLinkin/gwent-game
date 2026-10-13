import 'package:flutter/material.dart' hide Intent;
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/application/start_match.dart' show LocalMatchRequest;
import 'package:gwent/src/features/match/domain/match_session.dart' show LocalMatchMode;
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Row;

// Временные экраны партии без макетов: выбор колод перед партией и сообщение об ошибке. Их заменит экран выбора
// фракции и колоды (макет 7); остальные экраны партии (старт, пересдача, итоги) лежат в `start/` и `overlays/`.

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

/// Выбор колод перед партией; режим выбран в главном меню.
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
