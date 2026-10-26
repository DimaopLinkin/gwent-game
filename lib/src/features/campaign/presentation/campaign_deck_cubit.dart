import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/campaign/application/choose_campaign_deck.dart';
import 'package:gwent/src/features/campaign/application/get_campaign_deck.dart';
import 'package:gwent/src/features/campaign/application/list_campaign_decks.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_deck_state.dart';

/// Держатель экрана «Колода для боя»: колоды игрока с оценкой для кампании и выбор одной из них.
///
/// Выбор запоминается только по нажатию «В бой» или «Выбрать» ([confirm]): пролистывание списка настройки не меняет.
final class CampaignDeckCubit extends Cubit<CampaignDeckState> {
  /// Создаёт держатель; [nodeId] — узел, в бой на который идёт игрок.
  CampaignDeckCubit(this._list, this._get, this._choose, this._campaign, {this.nodeId})
    : super(const CampaignDeckLoading()) {
    unawaited(_load());
  }

  final ListCampaignDecks _list;
  final GetCampaignDeck _get;
  final ChooseCampaignDeck _choose;
  final LoadCampaign _campaign;

  /// Узел, в который идёт игрок; `null`, если колоду выбирают с тропы.
  final String? nodeId;

  Future<void> _load() async {
    try {
      final data = await _campaign();
      if (data == null) {
        if (!isClosed) emit(const CampaignDeckFailed());
        return;
      }
      final decks = await _list();
      final current = await _get();
      if (isClosed) return;
      final sorted = [
        ...decks.where((entry) => entry.isReady),
        ...decks.where((entry) => !entry.isReady),
      ];
      // Выбранная колода стоит первой.
      final chosen = sorted.where((entry) => entry.deck.id == current?.id).toList();
      emit(
        CampaignDeckLoaded(
          data: data,
          decks: [...chosen, ...sorted.where((entry) => !chosen.contains(entry))],
          selectedId: current?.id,
          node: nodeId == null ? null : data.catalog.nodesById[nodeId],
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(const CampaignDeckFailed());
    }
  }

  /// Читает колоды заново: игрок вернулся из конструктора.
  Future<void> reload() => _load();

  /// Игрок коснулся годной колоды.
  void select(String deckId) {
    if (state case final CampaignDeckLoaded loaded when loaded.decks.any((e) => e.deck.id == deckId && e.isReady)) {
      emit(loaded.select(deckId));
    }
  }

  /// Запоминает выбранную колоду. `true`, если выбор записан и можно идти дальше.
  Future<bool> confirm() async {
    final loaded = state;
    final id = loaded is CampaignDeckLoaded ? loaded.selectedId : null;
    if (id == null) return false;
    try {
      await _choose(id);
      return true;
    } on Object catch (error, stackTrace) {
      // Колода перестала годиться, пока экран был открыт: список читается заново.
      addError(error, stackTrace);
      unawaited(_load());
      return false;
    }
  }
}
