/// Тема справочника «Как играть» (ADR 0034, макет 16, раздел E): порядок тем в перечислении — порядок в списке и
/// в ссылках «Предыдущая» и «Следующая тема».
enum HowToTopic {
  /// Цель партии: раунды и кристаллы.
  goal('goal'),

  /// Рука, колода и сброс.
  handAndDeck('hand'),

  /// Ход и пас.
  turnAndPass('turn'),

  /// Ряды и сила карты.
  rowsAndPower('rows'),

  /// Погода.
  weather('weather'),

  /// Способности отрядов.
  abilities('abilities'),

  /// Особые карты.
  specials('specials'),

  /// Лидеры и фракции.
  leadersAndFactions('leaders')
  ;

  const HowToTopic(this.key);

  /// Короткое имя темы в адресе страницы.
  final String key;

  /// Тема с именем [key] в адресе; `null`, если такой нет.
  static HowToTopic? fromKey(String key) => values.where((topic) => topic.key == key).firstOrNull;

  /// Предыдущая тема; у первой — `null`.
  HowToTopic? get previous => index == 0 ? null : values[index - 1];

  /// Следующая тема; у последней — `null`.
  HowToTopic? get next => index == values.length - 1 ? null : values[index + 1];
}
