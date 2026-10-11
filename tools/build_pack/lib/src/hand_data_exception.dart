/// Данные `docs/hand` нельзя превратить в пакет: неизвестный тег, битая связь или неверное поле.
final class HandDataException implements Exception {
  /// Создаёт исключение со списком проблем [problems].
  const HandDataException(this.problems);

  /// Все найденные проблемы, по одной на строку.
  final List<String> problems;

  @override
  String toString() => 'HandDataException:\n${problems.join('\n')}';
}
