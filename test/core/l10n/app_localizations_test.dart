import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';

void main() {
  test('единственный язык интерфейса — русский', () {
    expect(AppLocalizations.supportedLocales, [const Locale('ru')]);
  });

  test('число карт склоняется по-русски', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

    expect([1, 2, 5, 11, 21, 22, 25].map(l10n.deckCardCount), [
      '1 карта',
      '2 карты',
      '5 карт',
      '11 карт',
      '21 карта',
      '22 карты',
      '25 карт',
    ]);
  });
}
