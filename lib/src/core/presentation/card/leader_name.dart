/// Делит полное имя лидера по первому двоеточию: «Фольтест: Король Темерии» → («Фольтест», «Король Темерии»).
/// Без двоеточия второй части нет.
(String, String?) splitLeaderName(String name) {
  final i = name.indexOf(': ');
  return i > 0 ? (name.substring(0, i), name.substring(i + 2)) : (name, null);
}

/// Короткое имя лидера для строки списка: персонаж и первая часть прозвища до запятой,
/// «Эмгыр вар Эмрейс: Белое Пламя, Пляшущее на Курганах Врагов» → «Эмгыр вар Эмрейс, Белое Пламя».
String shortLeaderName(String name) {
  final (character, nickname) = splitLeaderName(name);
  return nickname == null ? character : '$character, ${nickname.split(',').first}';
}
