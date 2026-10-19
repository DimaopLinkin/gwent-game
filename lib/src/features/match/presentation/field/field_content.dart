import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_content_mapper.dart';
import 'package:gwent/src/core/presentation/card/card_detail.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_weather.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Мост между партией и интерфейсом поля: по экземпляру карты из проекции даёт определение для правил и
/// готовые лица карт для рисования.
///
/// Тексты, арт и иконки берёт `CardContentMapper` из пакета контента, силу на столе и иней подставляет поле.
final class FieldContent {
  /// Создаёт мост над контентом партии и строками интерфейса [l10n].
  FieldContent({required this.content, required AppLocalizations l10n})
    : _mapper = CardContentMapper(pack: content.pack, l10n: l10n);

  /// Контент партии: пакет и справочник движка.
  final GameContent content;

  final CardContentMapper _mapper;

  /// Погода над рядом: мороз над ближним, мгла над дальним, ливень над осадным (шторм Скеллиге ложится на два
  /// ряда и рисуется теми же слоями).
  static GwentWeather weatherOf(Row row) => switch (row) {
    Row.melee => GwentWeather.frost,
    Row.ranged => GwentWeather.fog,
    Row.siege => GwentWeather.rain,
  };

  /// Иконка ряда.
  static GwentIcon rowIcon(Row row) => switch (row) {
    Row.melee => GwentIcon.rowMelee,
    Row.ranged => GwentIcon.rowRanged,
    Row.siege => GwentIcon.rowSiege,
  };

  /// Определение карты в справочнике движка.
  CardDefinition definition(CardInstance card) =>
      content.catalog.card(card.cardId) ?? (throw StateError('Карты ${card.cardId.value} нет в справочнике'));

  /// Определение отряда; `null`, если карта не отряд.
  UnitCardDefinition? unit(CardInstance card) => switch (definition(card)) {
    final UnitCardDefinition unit => unit,
    SpecialCardDefinition() => null,
  };

  /// Определение особой карты; `null`, если карта не особая.
  SpecialCardDefinition? special(CardInstance card) => switch (definition(card)) {
    final SpecialCardDefinition special => special,
    UnitCardDefinition() => null,
  };

  /// Обычный отряд: не герой. Его можно подменить Чучелом.
  bool isNormalUnit(CardInstance card) => unit(card)?.isHero == false;

  /// Базовая сила карты на поле: у особых карт ноль.
  int baseStrength(CardInstance card) => unit(card)?.strength ?? 0;

  /// Лицо и описание карты. [power] — сила на столе, [frosted] — иней на арте (ряд под погодой).
  CardDetail detail(CardInstance card, {int? power, bool frosted = false}) {
    final id = card.cardId.value;
    final rules = _mapper.pack.rules;
    final detail = switch (rules.squadCardsById[id]) {
      final squad? => _mapper.squad(squad, power: power, frosted: frosted),
      null => _mapper.byId(id),
    };
    return detail ?? (throw StateError('Карты $id нет в пакете контента'));
  }

  /// Лицо карты.
  CardFace face(CardInstance card, {int? power, bool frosted = false}) =>
      detail(card, power: power, frosted: frosted).face;

  /// Лидер и его описание; [used] — способность уже применена.
  CardDetail leader(LeaderId id, {bool used = false}) {
    final card = _mapper.pack.rules.leaderCardsById[id.value] ?? (throw StateError('Лидера ${id.value} нет в пакете'));
    return _mapper.leader(card, abilityUsed: used);
  }

  /// Лицо лидера для мини-карты на полосе игрока.
  LeaderCardFace leaderFace(LeaderId id, {bool used = false}) => leader(id, used: used).face as LeaderCardFace;

  /// Название фракции из пакета контента.
  String factionName(Faction faction) {
    final key = this.faction(faction).key;
    final fraction = content.pack.rules.fractionsById.values.where((fraction) => fraction.key == key).firstOrNull;
    return fraction == null ? '' : content.pack.text(fraction.nameKey);
  }

  /// Фракция колоды для герба и рубашки.
  GwentFaction faction(Faction faction) => switch (faction) {
    Faction.northernRealms => GwentFaction.northernRealms,
    Faction.nilfgaard => GwentFaction.nilfgaard,
    Faction.monsters => GwentFaction.monsters,
    Faction.scoiatael => GwentFaction.scoiatael,
    Faction.skellige => GwentFaction.skellige,
    Faction.neutral => GwentFaction.neutral,
  };
}
