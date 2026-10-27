import 'package:meta/meta.dart';

/// Карта в «Книге карт»: сколько копий открыто из скольких есть в игре.
@immutable
final class BookCard {
  /// Создаёт запись; [owned] не больше [total].
  const BookCard({required this.cardId, required this.name, required this.owned, required this.total});

  /// UUID карты или лидера.
  final String cardId;

  /// Название для порядка в сетке; закрытая карта своего имени не показывает.
  final String name;

  /// Открыто копий.
  final int owned;

  /// Всего копий в игре.
  final int total;

  /// Хотя бы одна копия открыта.
  bool get isOpen => owned > 0;

  @override
  bool operator ==(Object other) =>
      other is BookCard && other.cardId == cardId && other.owned == owned && other.total == total;

  @override
  int get hashCode => Object.hash(cardId, owned, total);
}

/// Раздел книги: фракция или общие карты. Отряды идут героями вперёд и от сильных к слабым.
@immutable
final class BookSection {
  /// Создаёт раздел; [fractionId] — `null` у общих карт.
  BookSection({
    required this.fractionId,
    required List<BookCard> squads,
    required List<BookCard> specials,
    required List<BookCard> leaders,
  }) : squads = List.unmodifiable(squads),
       specials = List.unmodifiable(specials),
       leaders = List.unmodifiable(leaders);

  /// Фракция раздела; `null` — общие карты (нейтральные, погода).
  final String? fractionId;

  /// Отряды и герои.
  final List<BookCard> squads;

  /// Особые карты.
  final List<BookCard> specials;

  /// Лидеры.
  final List<BookCard> leaders;

  /// Идентификатор раздела в маршруте.
  String get id => fractionId ?? CardBook.commonId;

  static int _owned(List<BookCard> cards) => cards.fold(0, (sum, card) => sum + card.owned);

  static int _total(List<BookCard> cards) => cards.fold(0, (sum, card) => sum + card.total);

  /// Открыто копий отрядов.
  int get openedSquads => _owned(squads);

  /// Всего копий отрядов.
  int get totalSquads => _total(squads);

  /// Открыто копий особых карт.
  int get openedSpecials => _owned(specials);

  /// Всего копий особых карт.
  int get totalSpecials => _total(specials);

  /// Открыто лидеров.
  int get openedLeaders => _owned(leaders);

  /// Всего лидеров.
  int get totalLeaders => _total(leaders);

  /// Открыто копий в разделе.
  int get opened => openedSquads + openedSpecials + openedLeaders;

  /// Всего копий в разделе.
  int get total => totalSquads + totalSpecials + totalLeaders;
}

/// «Книга карт»: открытое по фракциям. Счёт в копиях, как «Книга N/M» на тропе.
@immutable
final class CardBook {
  /// Создаёт книгу.
  CardBook(List<BookSection> sections) : sections = List.unmodifiable(sections);

  /// Идентификатор раздела общих карт.
  static const String commonId = 'common';

  /// Разделы: фракции с колодой в порядке пакета, затем общие карты.
  final List<BookSection> sections;

  /// Раздел по идентификатору маршрута или `null`.
  BookSection? section(String id) => sections.where((section) => section.id == id).firstOrNull;

  /// Открыто копий.
  int get opened => sections.fold(0, (sum, section) => sum + section.opened);

  /// Всего копий.
  int get total => sections.fold(0, (sum, section) => sum + section.total);
}
