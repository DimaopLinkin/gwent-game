import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_content_mapper.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_cubit.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_state.dart';
import 'package:gwent/src/features/deck_builder/presentation/editor/editor_actions.dart';
import 'package:gwent/src/features/deck_builder/presentation/editor/editor_filters.dart';
import 'package:gwent/src/features/deck_builder/presentation/editor/editor_grid.dart';
import 'package:gwent/src/features/deck_builder/presentation/editor/editor_header.dart';
import 'package:gwent/src/features/deck_builder/presentation/editor/editor_sheets.dart';
import 'package:gwent/src/features/deck_builder/presentation/editor/editor_stats.dart';

/// Конструктор колоды (макет 8): шапка с фракцией, названием и лидером, счётчики, подсказка, вкладки «Коллекция» и
/// «Колода», фильтры, сетка карт и кнопки сохранения.
///
/// Ждёт [DeckEditorCubit] выше по дереву. Экран не знает, откуда его открыли: он сообщает [onExit], когда игрок
/// вернулся назад или колода сохранена. Несохранённые правки при выходе теряются.
///
/// Чтобы встроить конструктор в другой сценарий (например, подготовку к сетевой партии), [banner] ставит плашку над
/// шапкой, [actionsBuilder] заменяет нижние кнопки, а [onSaved] получает сохранённую колоду вместо [onExit].
class DeckEditorScreen extends StatelessWidget {
  /// Создаёт экран.
  const DeckEditorScreen({super.key, required this.onExit, this.onSaved, this.banner, this.actionsBuilder});

  /// Игрок вернулся назад или колода сохранена (если не задан [onSaved]).
  final VoidCallback onExit;

  /// Колода сохранена; вместо [onExit] после сохранения. Параметр — идентификатор сохранённой колоды.
  final ValueChanged<String>? onSaved;

  /// Плашка над шапкой или `null`.
  final Widget? banner;

  /// Нижние кнопки вместо «Сохранить» или `null`, чтобы оставить стандартные.
  final Widget Function(BuildContext context, DeckEditorReady state)? actionsBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: BlocConsumer<DeckEditorCubit, DeckEditorState>(
        listenWhen: (previous, current) => current is DeckEditorSaved,
        listener: (context, state) {
          if (state is! DeckEditorSaved) return;
          (onSaved ?? (_) => onExit())(state.deckId);
        },
        builder: (context, state) => Column(
          children: [
            ScreenHeader(eyebrow: l10n.editorEyebrow, onBack: onExit, backLabel: l10n.editorBack),
            Expanded(
              child: switch (state) {
                DeckEditorLoading() || DeckEditorSaved() => const GameLoader(),
                DeckEditorFailed() => _Message(l10n.editorLoadFailed),
                DeckEditorNotFound() => _Message(l10n.editorNotFound),
                final DeckEditorReady ready => _EditorBody(
                  state: ready,
                  banner: banner,
                  actionsBuilder: actionsBuilder,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: GwentText.alegreya, fontSize: 17, color: GwentColors.textSecondary),
      ),
    ),
  );
}

class _EditorBody extends StatelessWidget {
  const _EditorBody({required this.state, required this.banner, required this.actionsBuilder});

  /// Ниже этой высоты (вместе с кнопками) шапка и счётчики прокручиваются вместе с картами.
  static const double _compactHeight = 610;

  final DeckEditorReady state;
  final Widget? banner;
  final Widget Function(BuildContext context, DeckEditorReady state)? actionsBuilder;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeckEditorCubit>();
    final mapper = CardContentMapper(pack: state.rules.pack, l10n: context.l10n);

    Widget top({bool withHint = true}) => Column(
      children: [
        if (banner case final banner?) Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 0), child: banner),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          child: EditorHeader(
            state: state,
            mapper: mapper,
            onPrevFaction: () => _changeFaction(context, -1),
            onNextFaction: () => _changeFaction(context, 1),
            onRename: cubit.rename,
            onPickLeader: () => _pickLeader(context, mapper),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: EditorStats(state: state),
        ),
        if (withHint)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: EditorHint(state: state),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: EditorTabs(state: state, onSelected: cubit.selectTab),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: EditorFilters(state: state, onSelected: cubit.selectFilter),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: EditorLegend(state: state, onToggleAvailable: cubit.toggleOnlyAvailable),
        ),
      ],
    );

    EditorGrid grid({bool shrinkWrap = false}) => EditorGrid(
      state: state,
      mapper: mapper,
      shrinkWrap: shrinkWrap,
      onTapCard: (id) => _tapCard(cubit, id),
      onLongPressCard: (id) => _preview(context, mapper, id),
    );

    final actions = Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: actionsBuilder?.call(context, state) ?? EditorActions(state: state, onSave: cubit.save),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight >= _compactHeight) {
          return Column(
            children: [
              top(),
              Expanded(child: grid()),
              actions,
            ],
          );
        }
        // Шапка и счётчики прокручиваются вместе с картами, поэтому подсказка закреплена над кнопками: причина отказа
        // видна, где бы ни была прокрутка.
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(children: [top(withHint: false), grid(shrinkWrap: true)]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: EditorHint(state: state),
            ),
            actions,
          ],
        );
      },
    );
  }

  void _tapCard(DeckEditorCubit cubit, String id) => switch (state.tab) {
    DeckEditorTab.collection => cubit.addCard(id),
    DeckEditorTab.deck => cubit.removeCard(id),
  };

  Future<void> _changeFaction(BuildContext context, int delta) async {
    final cubit = context.read<DeckEditorCubit>();
    final change = cubit.changeFaction(delta);
    if (change == null) return;
    final confirmed = await showFactionChangeSheet(
      context,
      fromName: state.faction.name,
      to: state.factionAt(change.target),
      removed: change.removed,
    );
    if (confirmed && context.mounted) cubit.applyFactionChange(change);
  }

  Future<void> _pickLeader(BuildContext context, CardContentMapper mapper) async {
    final cubit = context.read<DeckEditorCubit>();
    final leaderId = await showLeaderSheet(
      context,
      faction: state.faction,
      selectedId: state.draft.leaderId,
      faceOf: (id) => mapper.leader(state.rules.pack.rules.leaderCardsById[id]!).face,
    );
    if (leaderId != null && context.mounted) cubit.selectLeader(leaderId);
  }

  Future<void> _preview(BuildContext context, CardContentMapper mapper, String id) async {
    final cubit = context.read<DeckEditorCubit>();
    final l10n = context.l10n;
    final detail = mapper.byId(id);
    final card = state.rules.cardsById[id];
    if (detail == null || card == null) return;
    final copies = state.draft.copiesOf(id);
    final inCollection = state.tab == DeckEditorTab.collection;
    final blocked = state.rules.refusalToAdd(state.draft, card, owned: state.owned) != null;
    final limit = card.limit(state.owned);
    await showDeckCardPreview(
      context,
      detail: detail,
      meta: limit == 0
          ? l10n.editorPreviewLocked
          : l10n.editorPreviewMeta(card.isNeutral ? l10n.editorNeutralName : state.faction.name, copies, limit),
      actionLabel: inCollection ? l10n.editorPreviewAdd : l10n.editorPreviewRemove,
      onAction: inCollection
          ? (blocked ? null : () => cubit.addCard(id))
          : (copies > 0 ? () => cubit.removeCard(id) : null),
    );
  }
}
