import 'package:gwent_engine/gwent_engine.dart';

/// Набор правил партии: данные карт и версия движка. Игроки с разными наборами не могут играть вместе.
final class Ruleset extends Value {
  const Ruleset({required this.id, required this.hash, required this.engineVersion});

  /// Идентификатор пакета контента.
  final String id;

  /// `content_hash` пакета контента: разные данные карт означают разные игры.
  final String hash;

  /// Версия движка правил (`engineVersion`): тот же контент при другом коде правил тоже другая игра.
  final int engineVersion;

  @override
  List<Object?> get props => [id, hash, engineVersion];
}
