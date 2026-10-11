import 'package:gwent_content/gwent_content.dart';

/// Эффект способности из `docs/hand` и его общие параметры.
///
/// Значение параметра [SpecialCardTag] заменяется на UUID специальной карты с этим тегом при конвертации.
final class EffectMapping {
  /// Создаёт сопоставление с эффектом [effect] и параметрами [params].
  const EffectMapping(this.effect, [this.params = const {}]);

  /// Эффект.
  final EffectKey effect;

  /// Общие параметры способности.
  final Map<String, Object> params;
}

/// Ссылка на специальную карту по её `tag` в `special_cards`.
final class SpecialCardTag {
  /// Создаёт ссылку на карту с тегом [tag].
  const SpecialCardTag(this.tag);

  /// Тег карты.
  final String tag;
}

/// Порог Казни по ряду (раздел 9.4 и 10 `docs/hand/main.md`).
const int _scorchThreshold = 10;

/// `zones.tag` → ключ зоны.
const Map<String, ZoneKey> zoneKeysByTag = {
  'blizhniy_boy': ZoneKey.melee,
  'dalniy_boy': ZoneKey.ranged,
  'osadnye': ZoneKey.siege,
  'blizhniy_boy_dalniy_boy': ZoneKey.agile,
};

/// `squad_card_abilities.tag` → эффект. Параметры карт (`summons`, `transform_to`, `row`) добавляет конвертер.
const Map<String, EffectMapping> squadEffectsByTag = {
  'dvoinik': EffectMapping(EffectKey.muster),
  'shpion': EffectMapping(EffectKey.spy, {'draw': 2}),
  'provorstvo': EffectMapping(EffectKey.agile),
  'medik': EffectMapping(EffectKey.medic),
  'prochnaya_svyaz': EffectMapping(EffectKey.tightBond),
  'priliv_sil': EffectMapping(EffectKey.moraleBoost),
  'kazn': EffectMapping(EffectKey.scorchRow, {'threshold': _scorchThreshold}),
  'komandirskiy_rog': EffectMapping(EffectKey.commanderHorn),
  'primanka': EffectMapping(EffectKey.bait),
  'berserk': EffectMapping(EffectKey.berserk),
  'kazn_global': EffectMapping(EffectKey.scorch),
  'mardrem_squad': EffectMapping(EffectKey.mardroeme),
};

/// `special_card_abilities.tag` → эффект.
const Map<String, EffectMapping> specialEffectsByTag = {
  'kazn_ability': EffectMapping(EffectKey.scorch),
  'komandirskiy_rog_ability': EffectMapping(EffectKey.commanderHorn),
  'liven_ability': EffectMapping(EffectKey.weather, {
    'rows': ['siege'],
  }),
  'mgla_ability': EffectMapping(EffectKey.weather, {
    'rows': ['ranged'],
  }),
  'moroz_ability': EffectMapping(EffectKey.weather, {
    'rows': ['melee'],
  }),
  'chuchelo_ability': EffectMapping(EffectKey.decoy),
  'yasnoe_nebo_ability': EffectMapping(EffectKey.clearWeather),
  'mardrem_ability': EffectMapping(EffectKey.mardroeme),
  'shtorm_so_skellige_ability': EffectMapping(EffectKey.weather, {
    'rows': ['ranged', 'siege'],
  }),
};

/// `leader_card_abilities.tag` → эффект (раздел 10 `docs/hand/main.md`).
const Map<String, EffectMapping> leaderEffectsByTag = {
  'foltest_korol_temerii_ability': EffectMapping(EffectKey.playWeatherFromDeck, {'card_id': SpecialCardTag('mgla')}),
  'foltest_predvoditel_severa_ability': EffectMapping(EffectKey.clearWeather),
  'foltest_zavoevatel_ability': EffectMapping(EffectKey.leaderHorn, {'row': 'siege'}),
  'foltest_zhelezny_vladyka_ability': EffectMapping(EffectKey.scorchRow, {
    'row': 'siege',
    'threshold': _scorchThreshold,
  }),
  'foltest_syn_medella_ability': EffectMapping(EffectKey.scorchRow, {'row': 'ranged', 'threshold': _scorchThreshold}),
  'emgyr_var_emreys_yozh_iz_erlenvalda_ability': EffectMapping(EffectKey.playWeatherFromDeck, {
    'card_id': SpecialCardTag('liven'),
  }),
  'emgyr_var_emreys_imperator_nilfgaarda_ability': EffectMapping(EffectKey.revealOpponentHand, {'count': 3}),
  'emgyr_var_emreys_beloe_plamya_ability': EffectMapping(EffectKey.disableOpponentLeader),
  'emgyr_var_emreys_vlastelin_yuga_ability': EffectMapping(EffectKey.takeFromOpponentDiscard),
  'emgyr_var_emreys_zavoevatel_severa_ability': EffectMapping(EffectKey.randomMedic),
  'eredin_breacc_glas_korol_aen_elle_ability': EffectMapping(EffectKey.leaderHorn, {'row': 'melee'}),
  'eredin_breacc_glas_vladyka_tir_na_lia_ability': EffectMapping(EffectKey.returnFromDiscard),
  'eredin_breacc_glas_ubiytsa_oberona_ability': EffectMapping(EffectKey.discardAndDraw, {'discard': 2, 'draw': 1}),
  'eredin_breacc_glas_komandir_dikoy_ohoti_ability': EffectMapping(EffectKey.playAnyWeatherFromDeck),
  'eredin_breacc_glas_verolomny_ability': EffectMapping(EffectKey.doubleSpies),
  'francesca_findabair_istinnaya_elfka_ability': EffectMapping(EffectKey.playWeatherFromDeck, {
    'card_id': SpecialCardTag('moroz'),
  }),
  'francesca_findabair_koroleva_dol_blatanny_ability': EffectMapping(EffectKey.scorchRow, {
    'row': 'melee',
    'threshold': _scorchThreshold,
  }),
  'francesca_findabair_prekrasneyshaya_ability': EffectMapping(EffectKey.leaderHorn, {'row': 'ranged'}),
  'francesca_findabair_margaritka_iz_dolin_ability': EffectMapping(EffectKey.extraStartingCard, {'count': 1}),
  'francesca_findabair_nadezhda_aen_seidhe_ability': EffectMapping(EffectKey.optimizeAgile),
  'korol_bran_ability': EffectMapping(EffectKey.halveWeather),
  'krah_an_krait_ability': EffectMapping(EffectKey.shuffleDiscardsIntoDecks),
};

/// `fraction_abilities.tag` → перк (раздел 11 `docs/hand/main.md`).
const Map<String, EffectMapping> fractionEffectsByTag = {
  'northern_realms_fraction_ability': EffectMapping(EffectKey.drawOnRoundWin, {'count': 1}),
  'nilfgaardian_empire_fraction_ability': EffectMapping(EffectKey.winOnTie),
  'monsters_fraction_ability': EffectMapping(EffectKey.keepRandomUnit, {'count': 1}),
  'scoia_tael_fraction_ability': EffectMapping(EffectKey.chooseFirstPlayer),
  'skellige_fraction_ability': EffectMapping(EffectKey.reviveRandomUnits, {'count': 2, 'round': 3}),
};
