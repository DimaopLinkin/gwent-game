import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/deck_builder/application/get_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/application/save_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/presentation/deck_editor_state.dart';

/// Держатель конструктора колоды (макет 8): состав колоды, вкладки, фильтры и сохранение.
///
/// Числа правил (минимум отрядов, максимум особых карт, копии карт) берёт из `DeckRules`, а не из кода. Правила
/// сборки живут в домене (`DeckRules`, `DeckDraft`), держатель только применяет их к действиям игрока.
final class DeckEditorCubit extends Cubit<DeckEditorState> {
  /// Создаёт держатель и начинает читать правила и колоду.
  ///
  /// [deckId] `null` открывает новую колоду у первой фракции пакета. [newDeckName] называет новую колоду и
  /// подставляется, если игрок стёр название.
  DeckEditorCubit({
    required LoadDeckRules loadDeckRules,
    required GetDeck getDeck,
    required SaveDeck saveDeck,
    required String newDeckName,
    String? deckId,
  }) : _saveDeck = saveDeck,
       _fallbackName = newDeckName,
       super(const DeckEditorLoading()) {
    unawaited(_load(loadDeckRules, getDeck, deckId));
  }

  /// Сколько сообщение об отказе остаётся в строке подсказки.
  static const Duration messageDuration = Duration(milliseconds: 2400);

  final SaveDeck _saveDeck;
  final String _fallbackName;
  Timer? _messageTimer;

  Future<void> _load(LoadDeckRules loadDeckRules, GetDeck getDeck, String? deckId) async {
    try {
      final rules = await loadDeckRules();
      final deck = deckId == null ? null : await getDeck(deckId);
      if (isClosed) return;
      if (deckId != null && deck == null) {
        emit(const DeckEditorNotFound());
        return;
      }
      if (rules.factionInfos.isEmpty) throw StateError('в пакете нет фракций с колодой');
      final draft = deck == null
          ? DeckDraft(name: _fallbackName, factionId: rules.factionInfos.first.id)
          : _withoutUnknownCards(DeckDraft.of(deck), rules);
      final index = rules.factionInfos.indexWhere((faction) => faction.id == draft.factionId);
      if (index < 0) throw StateError('фракции колоды нет среди фракций с колодой: ${draft.factionId}');
      emit(
        DeckEditorReady(
          rules: rules,
          draft: draft,
          // Новую колоду собирают из коллекции, готовую смотрят в её составе.
          tab: deck == null ? DeckEditorTab.collection : DeckEditorTab.deck,
          filter: CardFilter.all,
          onlyAvailable: false,
          factionIndex: index,
          saving: false,
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(DeckEditorFailed(error));
    }
  }

  /// Карты, которых нет в пакете (пакет обновился), уходят из состава: показать и убрать их иначе нечем.
  DeckDraft _withoutUnknownCards(DeckDraft draft, DeckRules rules) => draft.copyWith(
    cards: {
      for (final MapEntry(key: id, value: copies) in draft.cards.entries)
        if (rules.cardsById.containsKey(id)) id: copies,
    },
  );

  DeckEditorReady? get _ready => switch (state) {
    final DeckEditorReady ready when !ready.saving => ready,
    _ => null,
  };

  /// Открывает вкладку [tab].
  void selectTab(DeckEditorTab tab) {
    final ready = _ready;
    if (ready == null || ready.tab == tab) return;
    emit(_copy(ready, tab: tab));
  }

  /// Включает фильтр [filter].
  void selectFilter(CardFilter filter) {
    final ready = _ready;
    if (ready == null || ready.filter == filter) return;
    emit(_copy(ready, filter: filter));
  }

  /// Переключает «Только доступные».
  void toggleOnlyAvailable() {
    final ready = _ready;
    if (ready == null) return;
    emit(_copy(ready, onlyAvailable: !ready.onlyAvailable));
  }

  /// Меняет название колоды.
  void rename(String name) {
    final ready = _ready;
    if (ready == null) return;
    emit(_copy(ready, draft: ready.draft.copyWith(name: name)));
  }

  /// Кладёт одну копию карты [cardId] в колоду. Если нельзя, в строке подсказки появляется причина.
  void addCard(String cardId) {
    final ready = _ready;
    final card = ready?.rules.cardsById[cardId];
    if (ready == null || card == null) return;
    final refusal = ready.rules.refusalToAdd(ready.draft, card);
    if (refusal != null) {
      _say(ready, EditorMessage(refusal, max: ready.rules.gameRules.maxSpecialCards));
      return;
    }
    emit(_moved(ready, ready.draft.withAdded(cardId), cardId));
  }

  /// Убирает одну копию карты [cardId] из колоды.
  void removeCard(String cardId) {
    final ready = _ready;
    if (ready == null || ready.draft.copiesOf(cardId) == 0) return;
    emit(_moved(ready, ready.draft.withRemoved(cardId), cardId));
  }

  /// Выбирает лидера [leaderId] своей фракции; лидера чужой фракции выбрать нельзя.
  void selectLeader(String leaderId) {
    final ready = _ready;
    if (ready == null || ready.faction.leader(leaderId)?.available != true) return;
    emit(_copy(ready, draft: ready.draft.copyWith(leaderId: leaderId)));
  }

  /// Готовит смену фракции на соседнюю: [delta] = -1 предыдущая, 1 следующая (по кругу).
  ///
  /// Возвращает смену, если она заденет колоду и нужно подтверждение; иначе меняет фракцию сразу и возвращает
  /// `null`. Подтверждённую смену применяет [applyFactionChange].
  FactionChange? changeFaction(int delta) {
    final ready = _ready;
    if (ready == null) return null;
    final count = ready.rules.factionInfos.length;
    final target = (ready.factionIndex + delta) % count;
    if (target == ready.factionIndex) return null;
    final change = FactionChange(target: target, removed: _ownCards(ready));
    if (change.removed == 0 && ready.draft.leaderId == null) {
      applyFactionChange(change);
      return null;
    }
    return change;
  }

  /// Меняет фракцию: карты прежней фракции уходят, нейтральные остаются, лидер выбирается заново.
  void applyFactionChange(FactionChange change) {
    final ready = _ready;
    if (ready == null || change.target == ready.factionIndex) return;
    final faction = ready.rules.factionInfos[change.target];
    final kept = {
      for (final MapEntry(key: id, value: copies) in ready.draft.cards.entries)
        if (ready.rules.cardsById[id]?.isNeutral ?? false) id: copies,
    };
    emit(
      DeckEditorReady(
        rules: ready.rules,
        draft: ready.draft.copyWith(factionId: faction.id, clearLeader: true, cards: kept),
        tab: DeckEditorTab.collection,
        filter: ready.filter,
        onlyAvailable: ready.onlyAvailable,
        factionIndex: change.target,
        saving: false,
      ),
    );
  }

  /// Сохраняет колоду и закрывает конструктор. Колоду без лидера сохранить нельзя.
  ///
  /// Колода, нарушающая правила, сохраняется черновиком: играть ей нельзя, но работа не пропадает.
  Future<void> save() async {
    final ready = _ready;
    final leaderId = ready?.leader?.id;
    if (ready == null || leaderId == null) return;
    _messageTimer?.cancel();
    emit(_copy(ready, saving: true, clearMessage: true));
    try {
      final name = ready.draft.name.trim();
      final saved = await _saveDeck(
        id: ready.draft.id,
        name: name.isEmpty ? _fallbackName : name,
        factionId: ready.draft.factionId,
        leaderId: leaderId,
        cards: ready.draft.cards,
      );
      if (isClosed) return;
      emit(DeckEditorSaved(saved.id));
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      // Собранная колода остаётся на экране: игрок может нажать «Сохранить» ещё раз.
      if (!isClosed) emit(_copy(ready, saving: false, saveFailed: true));
    }
  }

  int _ownCards(DeckEditorReady ready) => ready.draft.cards.entries
      .where((entry) => !(ready.rules.cardsById[entry.key]?.isNeutral ?? false))
      .fold(0, (sum, entry) => sum + entry.value);

  void _say(DeckEditorReady ready, EditorMessage message) {
    emit(_copy(ready, message: message));
    _messageTimer?.cancel();
    _messageTimer = Timer(messageDuration, () {
      if (isClosed) return;
      if (state case final DeckEditorReady current when current.message == message) {
        emit(_copy(current, clearMessage: true));
      }
    });
  }

  DeckEditorReady _moved(DeckEditorReady ready, DeckDraft draft, String cardId) {
    _messageTimer?.cancel();
    return _copy(ready, draft: draft, lastMoved: cardId, moveSerial: ready.moveSerial + 1, clearMessage: true);
  }

  DeckEditorReady _copy(
    DeckEditorReady ready, {
    DeckDraft? draft,
    DeckEditorTab? tab,
    CardFilter? filter,
    bool? onlyAvailable,
    bool? saving,
    EditorMessage? message,
    bool clearMessage = false,
    bool? saveFailed,
    String? lastMoved,
    int? moveSerial,
  }) => DeckEditorReady(
    rules: ready.rules,
    draft: draft ?? ready.draft,
    tab: tab ?? ready.tab,
    filter: filter ?? ready.filter,
    onlyAvailable: onlyAvailable ?? ready.onlyAvailable,
    factionIndex: ready.factionIndex,
    saving: saving ?? ready.saving,
    message: clearMessage ? null : message ?? ready.message,
    saveFailed: !clearMessage && (saveFailed ?? ready.saveFailed),
    lastMoved: lastMoved ?? ready.lastMoved,
    moveSerial: moveSerial ?? ready.moveSerial,
  );

  @override
  Future<void> close() {
    _messageTimer?.cancel();
    return super.close();
  }
}
