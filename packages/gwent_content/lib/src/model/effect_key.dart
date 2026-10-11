import 'package:gwent_content/src/model/ability_kind.dart';
import 'package:gwent_content/src/model/param_type.dart';

/// Закрытый список эффектов способностей, которые понимает формат пакета.
///
/// Логика эффектов живёт в движке; пакет задаёт только ключ эффекта и его параметры. Параметры складываются
/// из `params` способности и `ability_params` карты, ключи в них не пересекаются. Ссылки на правила даны
/// по разделам `docs/hand/main.md`.
enum EffectKey {
  // Карты отрядов (раздел 9.4).

  /// Шпион: карта уходит на сторону соперника, игрок берёт [ParamType.count] карт.
  spy('spy', {AbilityKind.squad}, [ParamSpec('draw', ParamType.count)]),

  /// Медик: разыграть обычный отряд из своего отбоя.
  medic('medic', {AbilityKind.squad}, []),

  /// Двойник: выложить из колоды и руки все копии карт из `summons` (связь несимметрична).
  muster('muster', {AbilityKind.squad}, [ParamSpec('summons', ParamType.squadCards)]),

  /// Прочная связь: сила умножается на число копий карты в ряду.
  tightBond('tight_bond', {AbilityKind.squad}, []),

  /// Прилив сил: +1 другим обычным отрядам ряда.
  moraleBoost('morale_boost', {AbilityKind.squad}, []),

  /// Командирский рог: отряд-источник рога или спецкарта в слоте рога.
  commanderHorn('commander_horn', {AbilityKind.squad, AbilityKind.special}, []),

  /// Казнь по ряду соперника `row`, если сила ряда не меньше `threshold`.
  scorchRow(
    'scorch_row',
    {AbilityKind.squad, AbilityKind.leader},
    [
      ParamSpec('row', ParamType.row),
      ParamSpec('threshold', ParamType.count),
    ],
  ),

  /// Казнь сильнейших обычных отрядов всего поля.
  scorch('scorch', {AbilityKind.squad, AbilityKind.special}, []),

  /// Приманка: уходя с поля, призывает созданную карту `summons`.
  bait('bait', {AbilityKind.squad}, [ParamSpec('summons', ParamType.squadCard)]),

  /// Берсерк: в ряду с Мардрёмом превращается в созданную карту `transform_to`.
  berserk('berserk', {AbilityKind.squad}, [ParamSpec('transform_to', ParamType.squadCard)]),

  /// Мардрём: отряд (Мышовур) или спецкарта в слоте рога, превращает Берсерков ряда.
  mardroeme('mardroeme', {AbilityKind.squad, AbilityKind.special}, []),

  /// Проворство. Картам не назначается: признак проворной карты это зона `agile`. Запись нужна для текстов.
  agile('agile', {AbilityKind.squad}, []),

  // Специальные карты (раздел 9.3).

  /// Погода на ряды `rows` обоих игроков.
  weather('weather', {AbilityKind.special}, [ParamSpec('rows', ParamType.rows)]),

  /// Снять всю погоду (Ясное небо, лидер «Предводитель Севера»).
  clearWeather('clear_weather', {AbilityKind.special, AbilityKind.leader}, []),

  /// Чучело: вернуть обычный отряд со своей стороны в руку.
  decoy('decoy', {AbilityKind.special}, []),

  // Лидеры (раздел 10).

  /// Взять из колоды карту погоды `card_id` и сразу сыграть её.
  playWeatherFromDeck('play_weather_from_deck', {AbilityKind.leader}, [ParamSpec('card_id', ParamType.weatherCard)]),

  /// Выбрать в колоде любую карту погоды и сразу сыграть её.
  playAnyWeatherFromDeck('play_any_weather_from_deck', {AbilityKind.leader}, []),

  /// Рог лидера в слот своего ряда `row` до конца раунда.
  leaderHorn('leader_horn', {AbilityKind.leader}, [ParamSpec('row', ParamType.row)]),

  /// Посмотреть `count` случайных карт руки соперника.
  revealOpponentHand('reveal_opponent_hand', {AbilityKind.leader}, [ParamSpec('count', ParamType.count)]),

  /// Пассивно: отключает способность лидера соперника.
  disableOpponentLeader('disable_opponent_leader', {AbilityKind.leader}, []),

  /// Взять обычный отряд из отбоя соперника в руку.
  takeFromOpponentDiscard('take_from_opponent_discard', {AbilityKind.leader}, []),

  /// Пассивно: Медик у обоих игроков выбирает отряд из отбоя случайно.
  randomMedic('random_medic', {AbilityKind.leader}, []),

  /// Вернуть обычный отряд из своего отбоя в руку.
  returnFromDiscard('return_from_discard', {AbilityKind.leader}, []),

  /// Сбросить `discard` карт из руки, затем выбрать `draw` карт в колоде.
  discardAndDraw(
    'discard_and_draw',
    {AbilityKind.leader},
    [
      ParamSpec('discard', ParamType.count),
      ParamSpec('draw', ParamType.count),
    ],
  ),

  /// Пассивно: сила шпионов у обоих игроков удваивается.
  doubleSpies('double_spies', {AbilityKind.leader}, []),

  /// Пассивно: при раздаче игрок берёт на `count` карт больше.
  extraStartingCard('extra_starting_card', {AbilityKind.leader}, [ParamSpec('count', ParamType.count)]),

  /// Переставить свои проворные отряды так, чтобы сила ближнего и дальнего рядов стала наибольшей.
  optimizeAgile('optimize_agile', {AbilityKind.leader}, []),

  /// Пассивно: на своей стороне погода уменьшает силу вдвое, а не до 1.
  halveWeather('halve_weather', {AbilityKind.leader}, []),

  /// Отбой каждого игрока замешивается в его колоду.
  shuffleDiscardsIntoDecks('shuffle_discards_into_decks', {AbilityKind.leader}, []),

  // Перки фракций (раздел 11).

  /// Королевства Севера: после выигранного раунда взять `count` карт в начале следующего.
  drawOnRoundWin('draw_on_round_win', {AbilityKind.fraction}, [ParamSpec('count', ParamType.count)]),

  /// Нильфгаард: победа в раунде при ничьей по очкам.
  winOnTie('win_on_tie', {AbilityKind.fraction}, []),

  /// Чудовища: после раунда `count` случайных карт отрядов остаются на поле.
  keepRandomUnit('keep_random_unit', {AbilityKind.fraction}, [ParamSpec('count', ParamType.count)]),

  /// Скоя'таэли: игрок решает, кто ходит первым.
  chooseFirstPlayer('choose_first_player', {AbilityKind.fraction}, []),

  /// Скеллиге: в начале раунда `round` из отбоя на поле возвращаются `count` случайных обычных отрядов.
  reviveRandomUnits(
    'revive_random_units',
    {AbilityKind.fraction},
    [
      ParamSpec('count', ParamType.count),
      ParamSpec('round', ParamType.count),
    ],
  )
  ;

  const EffectKey(this.key, this.kinds, this.params);

  /// Машинный ключ эффекта в пакете (`effect`).
  final String key;

  /// Таблицы способностей, в которых эффект допустим.
  final Set<AbilityKind> kinds;

  /// Параметры эффекта. Каждый обязателен; других параметров нет.
  final List<ParamSpec> params;

  /// Эффект по ключу или `null`, если формат его не знает.
  static EffectKey? fromKey(String key) {
    for (final effect in values) {
      if (effect.key == key) return effect;
    }
    return null;
  }
}
