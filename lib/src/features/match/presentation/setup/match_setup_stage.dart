import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_content_mapper.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_issue_text.dart';
import 'package:gwent/src/features/match/application/start_match.dart' show LocalMatchRequest;
import 'package:gwent/src/features/match/presentation/match_setup_cubit.dart';
import 'package:gwent/src/features/match/presentation/match_setup_state.dart';
import 'package:gwent/src/features/match/presentation/match_stages.dart';
import 'package:gwent/src/features/match/presentation/setup/deck_select_view.dart';
import 'package:gwent/src/features/match/presentation/setup/faction_select_view.dart';
import 'package:gwent/src/features/match/presentation/setup/leader_select_view.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;

/// Выбор фракции, лидера и колоды перед партией (макет 7): три экрана подряд для каждого места.
///
/// Показывает то, что говорит `MatchSetupCubit`. Системное «назад» на втором и третьем шагах и на втором месте
/// возвращает на предыдущий шаг, на первом шаге уводит из выбора ([onExit]). Когда выбор закончен, передаёт
/// запрос на партию в [onStart].
class MatchSetupStage extends StatelessWidget {
  /// Создаёт этап; [onEditDeck] открывает колоду с данным идентификатором в конструкторе.
  const MatchSetupStage({super.key, required this.onStart, required this.onEditDeck, required this.onExit});

  /// Выбор закончен: запрос на партию.
  final ValueChanged<LocalMatchRequest> onStart;

  /// Игрок хочет изменить колоду с идентификатором `deckId`.
  final ValueChanged<String> onEditDeck;

  /// Игрок вышел из выбора.
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => BlocConsumer<MatchSetupCubit, MatchSetupState>(
    listenWhen: (previous, current) => current is MatchSetupDone,
    listener: (context, state) {
      if (state is MatchSetupDone) onStart(state.request);
    },
    builder: (context, state) => switch (state) {
      MatchSetupLoading() || MatchSetupDone() => const SafeArea(child: Center(child: GameLoader())),
      MatchSetupFailed() => SafeArea(
        child: MatchPanel(
          title: context.l10n.matchSetupLoadFailed,
          actions: [(label: context.l10n.matchExit, onPressed: onExit, primary: true)],
        ),
      ),
      final MatchSetupReady ready => _Step(ready: ready, onEditDeck: onEditDeck, onExit: onExit),
    },
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.ready, required this.onEditDeck, required this.onExit});

  final MatchSetupReady ready;
  final ValueChanged<String> onEditDeck;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<MatchSetupCubit>();
    final mapper = CardContentMapper(pack: ready.rules.pack, l10n: l10n);
    final player = l10n.playerNumbered(ready.seat == Seat.one ? 1 : 2);
    CardFace faceOf(String leaderId) => mapper.leader(ready.rules.pack.rules.leaderCardsById[leaderId]!).face;
    String stepLabel(int step) => ready.isHotSeat ? l10n.setupStepSeat(player, step, 2) : l10n.setupStep(step, 2);
    void back() {
      if (!cubit.back()) onExit();
    }

    final faction = ready.faction;
    final leader = ready.leader;
    return PopScope(
      canPop: !ready.canStepBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) cubit.back();
      },
      child: switch (ready.step) {
        SetupStep.faction => FactionSelectView(
          eyebrow: stepLabel(1),
          factions: ready.rules.factionInfos,
          index: ready.factionIndex,
          onIndexChanged: cubit.showFaction,
          onConfirm: cubit.confirmFaction,
          onBack: back,
          confirmEnabled: !ready.busy,
        ),
        SetupStep.leader => LeaderSelectView(
          eyebrow: stepLabel(2),
          faction: faction,
          selectedId: ready.leaderId,
          faceOf: faceOf,
          onSelect: cubit.selectLeader,
          onConfirm: cubit.confirmLeader,
          onBack: back,
          busy: ready.busy,
        ),
        SetupStep.deck when leader != null => DeckSelectView(
          eyebrow: ready.isHotSeat ? l10n.deckSelectEyebrowSeat(player) : l10n.deckSelectEyebrow,
          choices: ready.decks,
          selectedId: ready.deckId,
          faction: (name: faction.name, look: GwentFaction.fromKey(faction.key)),
          leaderName: leader.name,
          leaderFace: faceOf(leader.id),
          issueText: DeckIssueText(pack: ready.rules.pack, l10n: l10n),
          playLabel: ready.isLastSeat ? l10n.deckSelectPlay : l10n.deckSelectNext,
          onSelect: cubit.selectDeck,
          onEdit: onEditDeck,
          onPlay: cubit.confirmDeck,
          onBack: back,
          busy: ready.busy,
        ),
        // На шаге колоды лидер всегда выбран; без него держатель не доходит до этого шага.
        SetupStep.deck => const SafeArea(child: Center(child: GameLoader())),
      },
    );
  }
}
