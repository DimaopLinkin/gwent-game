import 'package:gwent/src/features/content/domain/game_content.dart';

/// Состояние справочника «Как играть»: тексты есть всегда, а карты-примеры берутся из набора карт, когда он готов.
sealed class HowToPlayState {
  const HowToPlayState();
}

/// Набор карт грузится: страницы уже читаются, примеры на картах появятся следом.
final class HowToPlayLoading extends HowToPlayState {
  /// Создаёт состояние.
  const HowToPlayLoading();
}

/// Набор карт готов: можно показывать примеры на настоящих картах.
final class HowToPlayReady extends HowToPlayState {
  /// Создаёт состояние с контентом [content].
  const HowToPlayReady(this.content);

  /// Контент партии: из него берутся карты-примеры, названия и перки фракций.
  final GameContent content;
}

/// Набор карт не загрузился: справочник читается без примеров.
final class HowToPlayUnavailable extends HowToPlayState {
  /// Создаёт состояние.
  const HowToPlayUnavailable();
}
