import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/collection/domain/owned_cards.dart';

void main() {
  test('число открытых копий; у неоткрытой карты ноль', () {
    final collection = CardCollection(const {'a': 2, 'b': 1});

    expect(collection.copiesOf('a'), 2);
    expect(collection.copiesOf('b'), 1);
    expect(collection.copiesOf('c'), 0);
    expect(collection.total, 3);
  });

  test('записи с нулём копий отбрасываются, отрицательное число отклоняется', () {
    expect(CardCollection(const {'a': 0}), CardCollection.empty);
    expect(() => CardCollection(const {'a': -1}), throwsArgumentError);
  });

  test('снимок не меняется вслед за исходной картой и равен снимку с тем же составом', () {
    final source = {'a': 1};
    final collection = CardCollection(source);
    source['a'] = 5;

    expect(collection.copiesOf('a'), 1);
    expect(collection, CardCollection(const {'a': 1}));
    expect(collection.hashCode, CardCollection(const {'a': 1}).hashCode);
    expect(() => collection.copies['b'] = 1, throwsUnsupportedError);
  });
}
