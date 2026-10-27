import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_order.dart';

CollectionCard card(String name, {CollectionKind kind = CollectionKind.unit, int strength = 0}) => CollectionCard(
  id: 'id-$name',
  name: name,
  fractionId: 'f',
  isNeutral: false,
  kind: kind,
  maxCopies: 1,
  strength: strength,
);

List<String> names(Iterable<CollectionCard> cards) => [for (final card in cards) card.name];

void main() {
  group('порядок карт в конструкторе', () {
    test('герои, потом отряды, потом особые; погода после особых', () {
      final cards = [
        card('Погода', kind: CollectionKind.weather),
        card('Отряд', strength: 6),
        card('Особая', kind: CollectionKind.special),
        card('Герой', kind: CollectionKind.hero, strength: 10),
      ];

      expect(names(CollectionOrder.sort(cards)), ['Герой', 'Отряд', 'Особая', 'Погода']);
    });

    test('внутри группы по убыванию силы, при равной силе по имени, нулевая сила в конце', () {
      final cards = [
        card('Б', strength: 4),
        card('Камби'),
        card('А', strength: 4),
        card('В', strength: 7),
        card('Я', strength: 2),
      ];

      expect(names(CollectionOrder.sort(cards)), ['В', 'А', 'Б', 'Я', 'Камби']);
    });

    test('герои по убыванию силы, особые по имени', () {
      final cards = [
        card('Чучело', kind: CollectionKind.special),
        card('Керис', kind: CollectionKind.hero, strength: 10),
        card('Казнь', kind: CollectionKind.special),
        card('Олаф', kind: CollectionKind.hero, strength: 12),
        card('Мардрём', kind: CollectionKind.special),
      ];

      expect(names(CollectionOrder.sort(cards)), ['Олаф', 'Керис', 'Казнь', 'Мардрём', 'Чучело']);
    });

    test('порядок не зависит от порядка на входе и не меняет вход', () {
      final cards = [card('Б', strength: 4), card('А', strength: 4), card('В', strength: 7)];

      final reversed = names(CollectionOrder.sort(cards.reversed));

      expect(reversed, names(CollectionOrder.sort(cards)));
      expect(names(cards), ['Б', 'А', 'В']);
    });

    test('регистр и «ё» не ломают порядок по имени', () {
      final cards = [card('ёж', strength: 3), card('Ястреб', strength: 3), card('Ель', strength: 3)];

      expect(names(CollectionOrder.sort(cards)), ['ёж', 'Ель', 'Ястреб']);
    });

    test('группа карты: герои, отряды и особые с погодой', () {
      expect(card('a', kind: CollectionKind.hero).group, CollectionGroup.heroes);
      expect(card('a').group, CollectionGroup.units);
      expect(card('a', kind: CollectionKind.special).group, CollectionGroup.specials);
      expect(card('a', kind: CollectionKind.weather).group, CollectionGroup.specials);
    });
  });
}
