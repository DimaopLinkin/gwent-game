import 'dart:ui';

/// Цвета дизайн-системы стола (макет Claude Design, промпт 0, раздел «Цвет», `GwentColors`).
///
/// Имена токенов совпадают с макетом. Оттенки, которых нет среди токенов, но которые макет карты и компонентов
/// задаёт числом (латунь медальонов, пергамент плашки), собраны ниже с пометкой «оттенок»: так их не приходится
/// повторять литералами в виджетах.
abstract final class GwentColors {
  /// Фон стола.
  static const Color bg = Color(0xFF14110E);

  /// Полоса ряда, панели.
  static const Color surface = Color(0xFF221C16);

  /// Плашки, листы, диалоги.
  static const Color surfaceRaised = Color(0xFF2E261D);

  /// Разделители, рамки.
  static const Color line = Color(0xFF4A3C2C);

  /// Латунная окантовка.
  static const Color brass = Color(0xFF8C6A3F);

  /// Акцент, активное, фокус.
  static const Color gold = Color(0xFFC8A35B);

  /// Пергаментные плашки.
  static const Color parchment = Color(0xFFD9C9A3);

  /// Основной текст: 14,5:1 на [bg].
  static const Color textPrimary = Color(0xFFE8DCC2);

  /// Вторичный текст: 7,4:1 на [bg].
  static const Color textSecondary = Color(0xFFA99B80);

  /// Сила выше базовой (вместе со стрелкой ▲).
  static const Color buff = Color(0xFF7BC86A);

  /// Сила ниже базовой (вместе со стрелкой ▼). Только жирные цифры от 14 pt: контраст 4,4:1.
  static const Color debuff = Color(0xFFD2513F);

  /// Камень-жизнь.
  static const Color lifeGem = Color(0xFFB3261E);

  /// Блик камня-жизни.
  static const Color lifeGemHighlight = Color(0xFFE0574D);

  /// Тень камня-жизни.
  static const Color lifeGemDeep = Color(0xFF5A120E);

  /// Пустое гнездо потерянного камня.
  static const Color socket = Color(0xFF0E0B09);

  /// Мелкий текст ошибок: 6,1:1 на [bg], 5,5:1 на [surface].
  static const Color errorText = Color(0xFFE07462);

  /// Вспышка возврата силы к базовой (Ясное небо): [gold] 60 %.
  static const Color powerRestoredGlow = Color(0x99C8A35B);

  /// Текст на золоте.
  static const Color onGold = Color(0xFF1E160D);

  /// Текст на пергаменте.
  static const Color onParchment = Color(0xFF2A1F14);

  /// Подложка модальных окон: #0A0806, 72 %.
  static const Color scrim = Color(0xB80A0806);

  /// Затемнение под полным просмотром карты (88 %).
  static const Color scrimDetail = Color(0xE00A0806);

  /// Кольцо фокуса, 2 pt.
  static const Color focusRing = textPrimary;

  /// Верх градиента силы героя.
  static const Color heroGoldLight = Color(0xFFD8B66E);

  /// Низ градиента силы героя.
  static const Color heroGoldDark = Color(0xFFA8843F);

  /// Иней, погода.
  static const Color frostTint = Color(0xFFCDE4F5);

  /// Оттенок: светлая латунь (рамка особой карты, низ градиента героя).
  static const Color brassLight = Color(0xFFA8843F);

  /// Оттенок: тёмная латунь (обводка основной кнопки, тени медальонов).
  static const Color brassDark = Color(0xFF6E5230);

  /// Оттенок: самая тёмная латунь, обводка латунной монеты.
  static const Color brassDeep = Color(0xFF4A3520);

  /// Оттенок: цвет вырезов в иконке на латунной монете.
  static const Color brassCut = Color(0xFFB8944F);

  /// Оттенок: блик латунной монеты.
  static const Color brassHighlight = Color(0xFFD3B06A);

  /// Оттенок: блик золотого медальона героя и метки лидера.
  static const Color goldHighlight = Color(0xFFE6C67E);

  /// Оттенок: верх градиента пергаментной плашки.
  static const Color parchmentLight = Color(0xFFDDCEA9);

  /// Оттенок: низ градиента плашки на карте.
  static const Color parchmentDark = Color(0xFFCDBB92);

  /// Оттенок: низ градиента плашки полного просмотра.
  static const Color parchmentShade = Color(0xFFD2C199);

  /// Оттенок: блик пергаментного медальона силы.
  static const Color parchmentHighlight = Color(0xFFE8DBB8);

  /// Оттенок: тень пергаментного медальона силы.
  static const Color parchmentLow = Color(0xFFBFAE86);

  /// Оттенок: вторичный текст на пергаменте.
  static const Color onParchmentSecondary = Color(0xFF5A4632);

  /// Оттенок: цитата на пергаменте.
  static const Color onParchmentQuote = Color(0xFF4A3828);

  /// Оттенок: приглушённый элемент (использованная способность лидера).
  static const Color muted = Color(0xFF6B5F4C);

  /// Оттенок: заглушка арта.
  static const Color artPlaceholder = Color(0xFF332A21);

  /// Оттенок: светлая полоса заглушки арта.
  static const Color artPlaceholderStripe = Color(0xFF3A3026);

  /// Оттенок: кожа рубашки в центре.
  static const Color backLeather = Color(0xFF3A2D20);

  /// Оттенок: кожа рубашки по краям.
  static const Color backLeatherEdge = Color(0xFF1E1812);

  /// Оттенок: фон нажатой второстепенной кнопки.
  static const Color pressed = Color(0xFF17120E);

  /// Оттенок: фон недоступной основной кнопки.
  static const Color disabledFill = Color(0xFF3A3024);

  /// Оттенок: текст недоступной основной кнопки.
  static const Color disabledText = Color(0xFF7A6D58);

  /// Оттенок: дорожка включённого переключателя.
  static const Color switchTrackOn = Color(0xFF3A2E1D);

  /// Оттенок: фон панелей и недоступной второстепенной кнопки.
  static const Color panel = Color(0xFF1C1712);

  /// Оттенок: рамка панелей и недоступных элементов.
  static const Color panelLine = Color(0xFF3A2F23);

  /// Тёплая подсветка тёмной поверхности: кнопка «Пас», счёт ведущего.
  static const Color surfaceWarm = Color(0xFF3A2F22);

  /// Утопленная поверхность: кнопка-иконка, недоступная кнопка «Пас».
  static const Color surfaceSunken = Color(0xFF1A1511);

  /// Иконка и текст недоступного элемента на тёмном.
  static const Color disabledIcon = Color(0xFF5A4E3D);

  /// Рамка опасного действия («Сдаться»): приглушённый красный.
  static const Color dangerRing = Color(0xFFA8483E);

  /// Рамка панели подтверждения опасного действия.
  static const Color dangerPanelRing = Color(0xFF7A3A33);

  /// Поражение: заголовок итога матча.
  static const Color defeat = Color(0xFFC4655A);

  /// Проигравший: приглушённый цвет счёта и надписей.
  static const Color loserText = Color(0xFF8A7C64);

  /// Подпись, которая светлее вторичного текста, но слабее основного (надписи на тёмных панелях).
  static const Color textTertiary = Color(0xFFCFC3A8);
}
