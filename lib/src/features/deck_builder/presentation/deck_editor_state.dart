import 'package:gwent/src/features/collection/domain/owned_cards.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_order.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/faction_info.dart';
import 'package:meta/meta.dart';

/// Вкладка конструктора.
enum DeckEditorTab {
  /// Карты коллекции, которые можно добавить.
  collection,

  /// Карты, уже лежащие в колоде.
  deck,
}

/// Фильтр списка карт.
enum CardFilter {
  /// Все карты.
  all,

  /// Ближний бой (с проворными).
  melee,

  /// Дальний бой (с проворными).
  ranged,

  /// Осадные.
  siege,

  /// Герои.
  hero,

  /// Погода.
  weather,

  /// Особые карты.
  special
  ;

  /// Подходит ли карта под фильтр.
  bool accepts(CollectionCard card) => switch (this) {
    all => true,
    melee => card.placement == CollectionPlacement.melee || card.placement == CollectionPlacement.agile,
    ranged => card.placement == CollectionPlacement.ranged || card.placement == CollectionPlacement.agile,
    siege => card.placement == CollectionPlacement.siege,
    hero => card.kind == CollectionKind.hero,
    weather => card.kind == CollectionKind.weather,
    special => card.kind == CollectionKind.special,
  };
}

/// Сообщение в строке подсказки: почему карта не добавлена. Живёт недолго.
@immutable
final class EditorMessage {
  /// Создаёт сообщение об отказе [refusal]; [max] — предел особых карт.
  const EditorMessage(this.refusal, {this.max = 0});

  /// Причина отказа.
  final AddRefusal refusal;

  /// Предел особых карт для сообщения «Не больше N особых карт».
  final int max;

  @override
  bool operator ==(Object other) => other is EditorMessage && other.refusal == refusal && other.max == max;

  @override
  int get hashCode => Object.hash(refusal, max);
}

/// Смена фракции, которая заденет колоду: игроку нужно подтверждение.
@immutable
final class FactionChange {
  /// Создаёт смену на фракцию номер [target]; [removed] карт прежней фракции уйдут из колоды.
  const FactionChange({required this.target, required this.removed});

  /// Номер новой фракции среди `DeckRules.factionInfos`.
  final int target;

  /// Сколько карт прежней фракции уйдёт из колоды.
  final int removed;

  @override
  bool operator ==(Object other) => other is FactionChange && other.target == target && other.removed == removed;

  @override
  int get hashCode => Object.hash(target, removed);
}

/// Карта списка с тем, что про неё нужно показать.
@immutable
final class EditorCard {
  /// Создаёт запись списка.
  const EditorCard({required this.card, required this.copies, required this.blocked, required this.limit});

  /// Карта.
  final CollectionCard card;

  /// Сколько копий в колоде.
  final int copies;

  /// Карту сейчас нельзя добавить (все копии в колоде, герой уже есть или особых максимум).
  final bool blocked;

  /// Сколько копий можно положить в колоду: число из набора карт, в кампании не больше открытого.
  final int limit;

  /// Карта закрыта: в кампании она ещё не открыта (ADR 0033).
  bool get locked => limit == 0;
}

/// Карты одной группы сетки («Герои», «Отряды», «Особые»).
@immutable
final class EditorCardGroup {
  /// Создаёт группу.
  const EditorCardGroup({required this.group, required this.cards});

  /// Группа.
  final CollectionGroup group;

  /// Карты группы в порядке сетки.
  final List<EditorCard> cards;
}

/// Состояние конструктора колоды.
sealed class DeckEditorState {
  const DeckEditorState();
}

/// Колода и правила читаются.
final class DeckEditorLoading extends DeckEditorState {
  /// Создаёт состояние.
  const DeckEditorLoading();
}

/// Не удалось прочитать правила или колоду.
final class DeckEditorFailed extends DeckEditorState {
  /// Создаёт состояние с ошибкой [error].
  const DeckEditorFailed(this.error);

  /// Что пошло не так.
  final Object error;
}

/// Колоды с таким идентификатором нет (например, её удалили).
final class DeckEditorNotFound extends DeckEditorState {
  /// Создаёт состояние.
  const DeckEditorNotFound();
}

/// Колода сохранена: экран закрывается.
final class DeckEditorSaved extends DeckEditorState {
  /// Создаёт состояние.
  const DeckEditorSaved(this.deckId);

  /// Идентификатор сохранённой колоды: новой его выдаёт сохранение.
  final String deckId;
}

/// Колоду собирают.
@immutable
final class DeckEditorReady extends DeckEditorState {
  /// Создаёт состояние.
  DeckEditorReady({
    required this.rules,
    required this.draft,
    required this.tab,
    required this.filter,
    required this.onlyAvailable,
    required this.factionIndex,
    required this.saving,
    this.owned,
    this.message,
    this.saveFailed = false,
    this.lastMoved,
    this.moveSerial = 0,
  });

  /// Правила и справочник карт.
  final DeckRules rules;

  /// Состав колоды.
  final DeckDraft draft;

  /// Открытая вкладка.
  final DeckEditorTab tab;

  /// Фильтр списка.
  final CardFilter filter;

  /// Скрыть на вкладке «Коллекция» карты, которые добавить нельзя.
  final bool onlyAvailable;

  /// Номер фракции колоды среди `rules.factionInfos`.
  final int factionIndex;

  /// Колода сохраняется: кнопки не принимают нажатий.
  final bool saving;

  /// Открытые карты кампании (ADR 0033): колоду собирают только из них. `null` в свободной игре, где доступны все карты.
  final OwnedCards? owned;

  /// Конструктор открыт для кампании.
  bool get isCampaign => owned != null;

  /// Сообщение об отказе в строке подсказки.
  final EditorMessage? message;

  /// Колоду не удалось сохранить: собранное осталось на экране, можно нажать «Сохранить» ещё раз.
  final bool saveFailed;

  /// Последняя перемещённая карта (для анимации).
  final String? lastMoved;

  /// Сколько раз карты перемещали: меняется при каждом перемещении, даже той же карты.
  final int moveSerial;

  /// Фракция колоды.
  FactionInfo get faction => factionAt(factionIndex);

  /// Фракция номер [index] среди `rules.factionInfos`; в кампании её закрытые лидеры недоступны.
  FactionInfo factionAt(int index) => switch (owned) {
    final owned? => rules.factionInfos[index].withOwned(owned),
    null => rules.factionInfos[index],
  };

  /// Лидер колоды или `null`, если не выбран.
  LeaderInfo? get leader => switch (draft.leaderId) {
    final id? => faction.leader(id),
    null => null,
  };

  /// Счётчики колоды.
  late final DeckStats stats = rules.statsOf(draft);

  /// Проблемы колоды по правилам.
  late final List<DeckIssue> issues = rules.checkDraft(draft, owned: owned);

  /// Колода проходит правила и лидер выбран: её можно сохранить как готовую.
  bool get isValid => leader != null && issues.isEmpty;

  /// Меньше отрядов, чем нужно.
  bool get tooFewUnits => stats.units < rules.gameRules.minUnitCards;

  /// Больше особых карт, чем можно.
  bool get tooManySpecials => stats.specials > rules.gameRules.maxSpecialCards;

  /// Карты коллекции фракции в порядке конструктора (`CollectionOrder`), с копиями в колоде и признаком «добавить нельзя».
  late final List<EditorCard> collection = List.unmodifiable([
    for (final card in CollectionOrder.sort(rules.collectionFor(draft.factionId)))
      EditorCard(
        card: card,
        copies: draft.copiesOf(card.id),
        blocked: rules.refusalToAdd(draft, card, owned: owned) != null,
        limit: card.limit(owned),
      ),
  ]);

  /// Сколько карт коллекции можно добавить сейчас: число на вкладке «Коллекция».
  int get availableCount => collection.where((entry) => !entry.blocked).length;

  /// Карты открытой вкладки под фильтром.
  ///
  /// Вкладка «Колода» строится по составу колоды, а не по коллекции фракции: карту, которой нет в коллекции (чужая
  /// фракция после обновления пакета), видно и можно убрать.
  List<EditorCard> get visible => List.unmodifiable(switch (tab) {
    DeckEditorTab.collection => [
      for (final entry in collection)
        if (filter.accepts(entry.card) && (!onlyAvailable || !entry.blocked)) entry,
    ],
    DeckEditorTab.deck => [
      for (final card in CollectionOrder.sort(rules.allCards))
        if (filter.accepts(card) && draft.copiesOf(card.id) > 0)
          EditorCard(
            card: card,
            copies: draft.copiesOf(card.id),
            blocked: rules.refusalToAdd(draft, card, owned: owned) != null,
            limit: card.limit(owned),
          ),
    ],
  });

  /// Карты открытой вкладки по группам в порядке сетки; пустых групп нет.
  ///
  /// Метки групп в сетке показывают, только если групп больше одной.
  List<EditorCardGroup> get visibleGroups => List.unmodifiable([
    for (final group in CollectionGroup.values)
      if (visible.where((entry) => entry.card.group == group).toList() case final cards when cards.isNotEmpty)
        EditorCardGroup(group: group, cards: cards),
  ]);
}
