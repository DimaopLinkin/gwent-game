/// Способность отряда, которую показывает страница «Способности отрядов», и карта-пример к ней.
enum HowToAbility {
  /// Прочная связь.
  tightBond('9c77cdbb-2bc9-4485-870f-67b2fd40e0a5'), // Боец Синих Полосок

  /// Прилив сил.
  moraleBoost('20fcfed5-92e0-47e0-bdce-56709ed4d854'), // Каэдвенский осадный мастер

  /// Медик.
  medic('3aebd7ba-8c68-45da-b65c-3ad7bf55d261'), // Лекарь Бурой Хоругви

  /// Шпион.
  spy('6768791a-0af6-478c-846e-b8e8f9e0c406'), // Принц Стеннис

  /// Берсерк.
  berserk('95d0ab31-2400-4b3b-a7ed-67d6df9ddbf0'), // Берсерк

  /// Двойник.
  muster('d4074247-eb78-4d19-85a1-288ea6fe3c7a'), // Ведьма: Кухарка

  /// Казнь у отряда.
  scorch('f03e57f1-8203-4163-8489-9245166658ce'), // Принц-жаба

  /// Приманка.
  bait('e1c03179-ea73-468c-a8b2-72dff1998b92'), // Камби

  /// Командирский рог у отряда.
  commanderHorn('90d7625b-2f3b-4840-ac21-826a9046df83'), // Лютик

  /// Свойство героя: золотая рамка.
  hero('0025d364-b039-4807-a33b-73ce5cf6c767') // Вернон Роше
  ;

  const HowToAbility(this.cardId);

  /// UUID карты-примера в пакете контента.
  final String cardId;
}

/// Особая карта страницы «Особые карты» и её UUID в пакете контента.
enum HowToSpecial {
  /// Командирский рог.
  commanderHorn('47d44246-c663-4218-b537-b81929c5caf0'),

  /// Чучело.
  decoy('61ad290e-1f7b-4d02-bb71-c2b645b37ea6'),

  /// Мардрём.
  mardroeme('dafeabf0-b94f-4b4e-86d8-21822a8fee06'),

  /// Казнь.
  scorch('57b2a086-6cab-4406-a0e2-c28b0cb8b534')
  ;

  const HowToSpecial(this.cardId);

  /// UUID карты в пакете контента.
  final String cardId;
}

/// Карта погоды страницы «Погода» и её UUID в пакете контента.
enum HowToWeather {
  /// Мороз: ближний ряд.
  frost('c858b281-84d5-410a-9e63-45f9e61d6825'),

  /// Мгла: дальний ряд.
  fog('7da6c359-b0a6-45ff-a8de-f713f398b2b8'),

  /// Ливень: осадный ряд.
  rain('b60d66ee-d0be-45c1-9b64-890eea79ec85'),

  /// Шторм со Скеллиге: дальний и осадный ряды.
  storm('8da9ddd9-b5d9-40d0-96f9-4f6e6440740b'),

  /// Ясное небо: снимает погоду.
  clear('9454833b-22f2-4989-b039-2d0eee81ff1a')
  ;

  const HowToWeather(this.cardId);

  /// UUID карты в пакете контента.
  final String cardId;
}

/// Карты рядов на странице «Ряды и сила»: по ним показан пример поля и счёт.
abstract final class HowToRowExamples {
  /// Ближний ряд: Реданский пехотинец и Боец Синих Полосок.
  static const List<String> melee = ['2c855539-3b40-4c18-9f8c-f4943a0bb1f2', '9c77cdbb-2bc9-4485-870f-67b2fd40e0a5'];

  /// Дальний ряд: Кейра Мец.
  static const List<String> ranged = ['dcdef72f-f08d-48db-8b10-795122652e14'];

  /// Осадный ряд: Баллиста.
  static const List<String> siege = ['5b89b34c-561f-4a1d-b272-91daef135ec5'];
}

/// Лидер на странице «Лидеры и фракции»: Фольтест: Завоеватель.
abstract final class HowToLeaderExample {
  /// UUID карты лидера в пакете контента.
  static const String cardId = 'd8c7de0f-b935-47b6-a32d-2cc1c63326f3';
}
