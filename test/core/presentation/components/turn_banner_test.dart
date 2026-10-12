import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/turn_banner.dart';

import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';

double _titleSize(WidgetTester tester, String title) => tester.widget<Text>(find.text(title)).style!.fontSize!;

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('короткий заголовок 32 pt, длинный сначала 24 pt, затем переносится', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> pump(String title) => tester.pumpWidget(localizedApp(Center(child: TurnBanner(title: title))));

    await pump('Ваш ход');
    expect(_titleSize(tester, 'Ваш ход'), 32);

    await pump('Противник спасовал');
    expect(_titleSize(tester, 'Противник спасовал'), 24);

    const long = 'Противник спасовал и больше не будет играть в этом раунде';
    await pump(long);
    expect(_titleSize(tester, long), 24);
    expect(tester.getSize(find.text(long)).height, greaterThan(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('минимальная высота 72 pt, подзаголовок показан', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        const Center(
          child: TurnBanner(title: 'Раунд 2', subtitle: 'Вы ведёте 1 : 0'),
        ),
      ),
    );
    expect(tester.getSize(find.byType(TurnBanner)).height, greaterThanOrEqualTo(72));
    expect(find.text('Вы ведёте 1 : 0'), findsOneWidget);
  });

  testWidgets('«Ваш ход» в золоте, остальные нет', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        const Column(
          children: [
            TurnBanner(title: 'Ваш ход', kind: TurnBannerKind.yourTurn),
            TurnBanner(title: 'Раунд 2'),
          ],
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('Ваш ход')).style!.color,
      isNot(tester.widget<Text>(find.text('Раунд 2')).style!.color),
    );
  });

  group('показ', () {
    testWidgets('держится 1,6 с, потом уходит и сообщает; касания проходят сквозь баннер', (tester) async {
      var dismissed = 0;
      var taps = 0;
      const banner = TurnBanner(title: 'Ваш ход', kind: TurnBannerKind.yourTurn);
      await tester.pumpWidget(
        localizedApp(
          TurnBannerPresenter(
            banner: banner,
            onDismissed: () => dismissed++,
            child: Center(
              child: TextButton(onPressed: () => taps++, child: const Text('под баннером')),
            ),
          ),
        ),
      );
      await tester.pump(TurnBannerPresenter.transition);
      expect(find.text('Ваш ход'), findsOneWidget);
      await tester.tap(find.text('под баннером'));
      expect(taps, 1);

      await tester.pump(const Duration(milliseconds: 1300));
      expect(dismissed, 0);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Ваш ход'), findsNothing);
      expect(dismissed, 1);
    });

    testWidgets('новый баннер заменяет показанный и перезапускает отсчёт', (tester) async {
      Future<void> pump(TurnBanner? banner) => tester.pumpWidget(
        localizedApp(TurnBannerPresenter(banner: banner, child: const SizedBox.expand())),
      );
      await pump(const TurnBanner(title: 'Раунд 2'));
      await tester.pump(const Duration(milliseconds: 1000));
      await pump(const TurnBanner(title: 'Ваш ход'));
      await tester.pump(TurnBannerPresenter.transition);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Ваш ход'), findsOneWidget);
      expect(find.text('Раунд 2'), findsNothing);

      await pump(null);
      await tester.pumpAndSettle();
      expect(find.text('Ваш ход'), findsNothing);
    });
  });
}
