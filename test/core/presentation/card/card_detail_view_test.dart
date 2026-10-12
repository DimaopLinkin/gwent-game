import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/card/card_detail.dart';
import 'package:gwent/src/core/presentation/card/card_detail_view.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/card/parts/card_detail_plaque.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';

import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';

const _shortDetail = CardDetail(
  face: UnitCardFace(
    art: null,
    name: 'Олаф',
    faction: GwentFaction.skellige,
    basePower: 12,
    row: GwentIcon.rowAgile,
    ability: GwentIcon.abilityMoraleBoost,
  ),
  meta: 'Скеллиге · Ближний бой / Дальний бой · Отряд',
  abilities: [
    CardAbilityLine(
      icon: GwentIcon.abilityMoraleBoost,
      name: 'Прилив сил',
      description: 'Даёт +1 к силе всем отрядам в своём ряду, кроме себя.',
    ),
  ],
  quote: 'Многие пытались победить Олафа.',
);

final _longDetail = CardDetail(
  face: const LeaderCardFace(
    art: null,
    name: 'Эмгыр вар Эмрейс: Белое Пламя, Пляшущее на Курганах Врагов',
    faction: GwentFaction.nilfgaard,
  ),
  meta: 'Нильфгаард · Лидер · способность доступна',
  abilities: [
    for (var i = 0; i < 4; i++)
      const CardAbilityLine(
        icon: GwentIcon.iconLeader,
        name: 'Способность лидера',
        description:
            'Уничтожает самый сильный дальнобойный отряд или отряды противника, если общая сила его дальнобойных '
            'отрядов больше или равна 10.',
      ),
  ],
  quote: 'Императоры владеют империями, но двумя вещами владеть не могут: своим сердцем и своим временем.',
);

/// Экран iPhone 390×844 с безопасными зонами 59 и 34, как в макете.
void _iphone(WidgetTester tester, {Size size = const Size(390, 844), double top = 59, double bottom = 34}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, CardDetail detail) async {
  await tester.pumpWidget(
    localizedApp(
      Builder(
        builder: (context) => TextButton(onPressed: () => showCardDetail(context, detail), child: const Text('open')),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

final Finder _cardSlot = find.byWidgetPredicate((widget) => widget is LayoutId && widget.id == CardDetailSlot.card);

Rect _rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

void main() {
  // Высота пергамента зависит от метрик шрифта, поэтому меряем настоящими шрифтами.
  setUpAll(loadDesignFonts);

  testWidgets('короткое описание: карта в полный размер, всё внутри безопасной зоны', (tester) async {
    _iphone(tester);
    await _open(tester, _shortDetail);

    final card = _rectOf(tester, _cardSlot);
    expect(card.size, Size(CardSize.full.metrics.width, CardSize.full.metrics.height));
    expect(card.top, 59);
    final plaque = _rectOf(tester, find.byType(CardDetailPlaque));
    expect(plaque.width, CardDetailLayoutDelegate.plaqueWidth);
    expect(plaque.top, card.bottom + CardDetailLayoutDelegate.gap);
    final hint = _rectOf(tester, find.text('Свайп вниз или тап вне карты — закрыть'));
    expect(hint.bottom, lessThanOrEqualTo(844 - 34));
  });

  testWidgets('длинное описание: карта сжимается не меньше 80 %, пергамент прокручивается', (tester) async {
    _iphone(tester, size: const Size(320, 568), top: 20, bottom: 0);
    await _open(tester, _longDetail);
    expect(tester.takeException(), isNull);

    final card = _rectOf(tester, _cardSlot);
    expect(card.height, closeTo(CardSize.full.metrics.height * CardDetailLayoutDelegate.minScale, 0.01));
    final hint = _rectOf(tester, find.text('Свайп вниз или тап вне карты — закрыть'));
    expect(hint.bottom, lessThanOrEqualTo(568));
    final scroll = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    expect(scroll.controller?.hasClients ?? true, isTrue);
    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('на узком экране карта не шире экрана', (tester) async {
    _iphone(tester, size: const Size(300, 900), top: 20, bottom: 0);
    await _open(tester, _shortDetail);
    expect(_rectOf(tester, _cardSlot).width, lessThanOrEqualTo(300 - 32));
  });

  testWidgets('тап по карте и пергаменту не закрывает, тап вне — закрывает', (tester) async {
    _iphone(tester);
    await _open(tester, _shortDetail);

    await tester.tap(find.descendant(of: find.byType(CardDetailView), matching: find.byType(GwentCard)));
    await tester.tap(find.byType(CardDetailPlaque));
    await tester.pumpAndSettle();
    expect(find.byType(CardDetailView), findsOneWidget);

    await tester.tapAt(const Offset(195, 830));
    await tester.pumpAndSettle();
    expect(find.byType(CardDetailView), findsNothing);
  });

  testWidgets('короткий свайп вниз возвращает просмотр, длинный — закрывает', (tester) async {
    _iphone(tester);
    await _open(tester, _shortDetail);
    final card = find.descendant(of: find.byType(CardDetailView), matching: find.byType(GwentCard));

    await tester.drag(card, const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(find.byType(CardDetailView), findsOneWidget);
    expect(_rectOf(tester, _cardSlot).top, 59);

    await tester.drag(card, const Offset(0, 140));
    await tester.pumpAndSettle();
    expect(find.byType(CardDetailView), findsNothing);
  });

  testWidgets('пергамент показывает имя и титул, строку типа, способности и цитату', (tester) async {
    _iphone(tester);
    await _open(tester, _longDetail);
    final plaque = find.byType(CardDetailPlaque);
    Finder inPlaque(String text) => find.descendant(of: plaque, matching: find.text(text));

    expect(inPlaque('Эмгыр вар Эмрейс'), findsOneWidget);
    expect(inPlaque('Белое Пламя, Пляшущее на Курганах Врагов'), findsOneWidget);
    expect(inPlaque('Нильфгаард · Лидер · способность доступна'), findsOneWidget);
    expect(inPlaque('Способность лидера'), findsNWidgets(4));
    expect(inPlaque(_longDetail.quote!), findsOneWidget);
  });
}
