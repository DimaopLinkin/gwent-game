import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/domain/card_book.dart';
import 'package:gwent/src/features/collection/domain/collection_repository.dart';
import 'package:gwent_content/gwent_content.dart';
import 'package:meta/meta.dart';

/// «Книга карт» вместе с пакетом, из которого взяты названия и лица карт.
@immutable
final class LoadedCardBook {
  /// Создаёт результат.
  const LoadedCardBook({required this.data, required this.book});

  /// Каталог и пакет с текстами.
  final CampaignData data;

  /// Открытое по фракциям.
  final CardBook book;
}

/// Сценарий: «Книга карт», открытые карты по фракциям.
final class LoadCardBook {
  /// Создаёт сценарий.
  const LoadCardBook(this._campaign, this._collection);

  final LoadCampaign _campaign;
  final CollectionRepository _collection;

  /// Книга сейчас; `null`, если каталога кампании нет.
  Future<LoadedCardBook?> call() async {
    final data = await _campaign();
    if (data == null) return null;
    final rules = data.pack.rules;
    final owned = await _collection.load();
    BookCard entry(String id, String nameKey, int total) => BookCard(
      cardId: id,
      name: data.text(nameKey),
      owned: owned.copiesOf(id).clamp(0, total),
      total: total,
    );
    List<BookCard> byName(Iterable<BookCard> cards) => [...cards]..sort((a, b) => _byName(a.name, b.name));

    BookSection section(Fraction? fraction) {
      bool mine(String fractionId) =>
          fraction == null ? !rules.fractionsById[fractionId]!.isDeck : fractionId == fraction.id;
      // Герои, затем отряды; в обеих группах от сильных к слабым, при равной силе по имени.
      final squads = rules.squadCards.where((card) => mine(card.fractionId)).toList()
        ..sort((a, b) {
          final byHero = (b.isHero ? 1 : 0).compareTo(a.isHero ? 1 : 0);
          if (byHero != 0) return byHero;
          final byStrength = b.strength.compareTo(a.strength);
          return byStrength != 0 ? byStrength : _byName(data.text(a.nameKey), data.text(b.nameKey));
        });
      return BookSection(
        fractionId: fraction?.id,
        squads: [for (final card in squads) entry(card.id, card.nameKey, card.count)],
        specials: byName([
          for (final card in rules.specialCards)
            if (mine(card.fractionId)) entry(card.id, card.nameKey, card.count),
        ]),
        leaders: byName([
          for (final card in rules.leaderCards)
            if (mine(card.fractionId)) entry(card.id, card.nameKey, 1),
        ]),
      );
    }

    return LoadedCardBook(
      data: data,
      book: CardBook([
        for (final fraction in rules.fractions)
          if (fraction.isDeck) section(fraction),
        section(null),
      ]),
    );
  }

  static int _byName(String a, String b) =>
      a.toLowerCase().replaceAll('ё', 'е').compareTo(b.toLowerCase().replaceAll('ё', 'е'));
}
