/// Именованные слоты иконок дизайн-системы (макет, раздел «Иконки» и «Гербы фракций»).
///
/// Слот — это имя, а не картинка: виджеты ссылаются на [GwentIcon], а файл лежит в `assets/icons/<файл>.svg`.
/// Чтобы заменить иконку (например, на символику из оригинала в личной сборке), достаточно положить другой SVG
/// с тем же именем файла. Контракт файла описан в `docs/adr/0009-design-system.md`.
enum GwentIcon {
  /// Ряд ближнего боя.
  rowMelee('row_melee'),

  /// Ряд дальнего боя.
  rowRanged('row_ranged'),

  /// Осадный ряд.
  rowSiege('row_siege'),

  /// Проворство: ближний или дальний ряд.
  rowAgile('row_agile'),

  /// Двойник.
  abilityTwin('ability_muster'),

  /// Шпион.
  abilitySpy('ability_spy'),

  /// Медик.
  abilityMedic('ability_medic'),

  /// Прочная связь.
  abilityTightBond('ability_tight_bond'),

  /// Прилив сил.
  abilityMoraleBoost('ability_morale_boost'),

  /// Казнь.
  abilityScorch('ability_scorch'),

  /// Командирский рог.
  abilityCommanderHorn('ability_commander_horn'),

  /// Приманка: призыв карты на место ушедшей.
  abilityAvenger('ability_avenger'),

  /// Берсерк.
  abilityBerserk('ability_berserk'),

  /// Мардрём.
  abilityMardroeme('ability_mardroeme'),

  /// Мороз.
  weatherFrost('weather_frost'),

  /// Мгла.
  weatherFog('weather_fog'),

  /// Ливень.
  weatherRain('weather_rain'),

  /// Шторм со Скеллиге.
  weatherSkelligeStorm('weather_skellige_storm'),

  /// Ясное небо.
  weatherClear('weather_clear'),

  /// Особая карта «Чучело».
  specialDecoy('special_decoy'),

  /// Колода.
  iconDeck('deck'),

  /// Сброс.
  iconDiscard('discard'),

  /// Рука.
  iconHand('hand'),

  /// Лидер.
  iconLeader('leader'),

  /// Лидирует по счёту.
  iconCrownLeading('crown_leading'),

  /// Камень-жизнь.
  iconLifeGem('life_gem'),

  /// Камень потерян.
  iconLifeGemLost('life_gem_lost'),

  /// Сила ▲.
  iconPowerUp('power_up'),

  /// Сила ▼.
  iconPowerDown('power_down'),

  /// Wi-Fi: способ соединения в сетевой игре.
  iconWifi('wifi'),

  /// Bluetooth: способ соединения в сетевой игре.
  iconBluetooth('bluetooth'),

  /// Wi-Fi выключен или связь потеряна.
  iconWifiOff('wifi_off'),

  /// Локальная сеть: доступ к ней нужен для поиска соперника.
  iconLocalNetwork('local_network'),

  /// Замок: доступ запрещён.
  iconLock('lock'),

  /// Пауза.
  iconPause('pause'),

  /// Крест: ошибка подключения.
  iconFail('fail'),

  /// Версия: приложения у игроков не совпадают.
  iconVersion('version'),

  /// QR-код.
  iconQr('qr'),

  /// Герб Королевств Севера.
  crestNorthernRealms('crest_northern_realms', isCrest: true),

  /// Герб Нильфгаарда.
  crestNilfgaard('crest_nilfgaard', isCrest: true),

  /// Герб Чудовищ.
  crestMonsters('crest_monsters', isCrest: true),

  /// Герб Скоя'таэлей.
  crestScoiatael('crest_scoiatael', isCrest: true),

  /// Герб Скеллиге.
  crestSkellige('crest_skellige', isCrest: true)
  ;

  const GwentIcon(this.fileName, {this.isCrest = false});

  /// Имя файла без расширения в `assets/icons/`.
  final String fileName;

  /// Герб: рисуется своими цветами и не перекрашивается.
  final bool isCrest;

  /// Особые карты «Командирский рог», «Казнь» и «Мардрём» используют иконки своих способностей.
  static const GwentIcon specialCommanderHorn = abilityCommanderHorn;

  /// Иконка особой карты «Казнь».
  static const GwentIcon specialScorch = abilityScorch;

  /// Иконка особой карты «Мардрём».
  static const GwentIcon specialMardroeme = abilityMardroeme;

  /// Путь к файлу в ассетах.
  String get assetPath => 'assets/icons/$fileName.svg';
}
