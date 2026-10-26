import 'package:gwent/src/features/campaign/application/load_card_book.dart';
import 'package:meta/meta.dart';

/// Состояние «Книги карт».
@immutable
sealed class CardBookState {
  const CardBookState();
}

/// Книга загружается.
final class CardBookLoading extends CardBookState {
  /// Создаёт состояние.
  const CardBookLoading();
}

/// Каталога кампании нет или книга не прочиталась.
final class CardBookUnavailable extends CardBookState {
  /// Создаёт состояние.
  const CardBookUnavailable();
}

/// Книга готова.
final class CardBookReady extends CardBookState {
  /// Создаёт состояние.
  const CardBookReady(this.loaded);

  /// Книга с пакетом.
  final LoadedCardBook loaded;
}
