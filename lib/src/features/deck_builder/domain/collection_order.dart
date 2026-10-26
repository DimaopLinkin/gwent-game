import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';

/// Порядок карт в сетке конструктора, как в TW3: сверху самые сильные, снизу самые слабые.
///
/// Герои, затем отряды (у обеих групп по убыванию силы, при равной силе по имени; карты с нулевой силой в конце), затем
/// особые карты по имени и после них погода по имени. Порядок не зависит от числа копий в колоде, поэтому при добавлении
/// и удалении карты остаются на местах.
abstract final class CollectionOrder {
  /// Возвращает копию [cards] в порядке конструктора.
  static List<CollectionCard> sort(Iterable<CollectionCard> cards) => [...cards]..sort(compare);

  /// Сравнивает две карты по порядку конструктора.
  static int compare(CollectionCard a, CollectionCard b) {
    final byGroup = a.group.index.compareTo(b.group.index);
    if (byGroup != 0) return byGroup;
    if (a.group != CollectionGroup.specials) {
      final byStrength = b.strength.compareTo(a.strength);
      if (byStrength != 0) return byStrength;
    } else {
      final byKind = (a.kind == CollectionKind.weather ? 1 : 0).compareTo(b.kind == CollectionKind.weather ? 1 : 0);
      if (byKind != 0) return byKind;
    }
    final byName = _nameKey(a.name).compareTo(_nameKey(b.name));
    if (byName != 0) return byName;
    final byFullName = a.name.compareTo(b.name);
    return byFullName != 0 ? byFullName : a.id.compareTo(b.id);
  }

  /// Имя без регистра и с «ё» как «е»: так «Ёж» стоит среди слов на «Е», а не после «Я».
  static String _nameKey(String name) => name.toLowerCase().replaceAll('ё', 'е');
}
