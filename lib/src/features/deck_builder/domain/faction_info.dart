import 'package:meta/meta.dart';

/// Фракция, из которой можно собрать колоду: то, что нужно экрану выбора фракции и лидера (макет 7).
///
/// Тексты уже взяты из строк пакета контента, поэтому экран не знает ни о пакете, ни о ключах строк.
@immutable
final class FactionInfo {
  /// Создаёт описание фракции.
  FactionInfo({
    required this.id,
    required this.key,
    required this.name,
    required this.perk,
    required List<LeaderInfo> leaders,
  }) : leaders = List.unmodifiable(leaders);

  /// UUID фракции.
  final String id;

  /// Машинный ключ фракции в пакете, например `skellige`.
  final String key;

  /// Название.
  final String name;

  /// Что делает способность (перк) фракции; пустая строка, если у фракции её нет.
  final String perk;

  /// Лидеры фракции в порядке пакета; у каждой фракции с колодой есть хотя бы один.
  final List<LeaderInfo> leaders;

  /// Лидер с UUID [leaderId] или `null`, если он не из этой фракции.
  LeaderInfo? leader(String leaderId) {
    for (final leader in leaders) {
      if (leader.id == leaderId) return leader;
    }
    return null;
  }
}

/// Карта лидера в виде, понятном экрану выбора.
@immutable
final class LeaderInfo {
  /// Создаёт описание лидера.
  const LeaderInfo({
    required this.id,
    required this.factionId,
    required this.name,
    required this.ability,
    this.available = true,
  });

  /// UUID карты лидера.
  final String id;

  /// UUID фракции лидера.
  final String factionId;

  /// Полное имя, например «Фольтест: Король Темерии». Часть до двоеточия — имя персонажа, после — прозвище.
  final String name;

  /// Что делает способность лидера.
  final String ability;

  /// Есть ли лидер в коллекции игрока. Пока коллекции нет (все карты пакета доступны сразу, раздел 2.2
  /// `docs/hand/main.md`), это всегда `true`; экран уже умеет показывать недоступного лидера с замком.
  final bool available;
}
