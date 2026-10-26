import 'package:meta/meta.dart';

/// Коротко о кампании для главного меню: где игрок сейчас.
@immutable
final class CampaignSummary {
  /// Создаёт сводку.
  const CampaignSummary({
    required this.chapterNumber,
    required this.chapterName,
    required this.passed,
    required this.total,
    required this.started,
  });

  /// Номер текущей главы.
  final int chapterNumber;

  /// Название текущей главы.
  final String chapterName;

  /// Пройдено узлов в текущей главе.
  final int passed;

  /// Всего узлов в текущей главе.
  final int total;

  /// Кампания начата: «Первая партия» пройдена и стартовый набор выдан.
  final bool started;

  @override
  bool operator ==(Object other) =>
      other is CampaignSummary &&
      other.chapterNumber == chapterNumber &&
      other.chapterName == chapterName &&
      other.passed == passed &&
      other.total == total &&
      other.started == started;

  @override
  int get hashCode => Object.hash(chapterNumber, chapterName, passed, total, started);
}
